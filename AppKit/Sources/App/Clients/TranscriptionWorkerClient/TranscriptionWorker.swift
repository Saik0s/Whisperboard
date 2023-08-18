
import AppDevUtils
import BackgroundTasks
import Combine
import ComposableArchitecture
import Dependencies
import IdentifiedCollections
import UIKit

// MARK: - TranscriptionWorker

protocol TranscriptionWorker: AnyObject {
  var currentTaskID: TranscriptionTask.ID? { get }
  func enqueueTask(_ task: TranscriptionTask)
  func removeTask(with id: TranscriptionTask.ID)
  func removeAllTasks()
  func getAllTasks() -> IdentifiedArrayOf<TranscriptionTask>
  func tasksStream() -> AsyncStream<IdentifiedArrayOf<TranscriptionTask>>
  func isProcessingStream() -> AsyncStream<Bool>
  func registerForProcessingTask()
}

// MARK: - TranscriptionWorkerImpl

final class TranscriptionWorkerImpl: TranscriptionWorker {
  var currentTaskID: TranscriptionTask.ID?

  private let processingTaskIdentifier = "me.igortarasenko.Whisperboard"
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  @Published private var isProcessing: Bool = false
  @Published private var taskQueue: LockIsolated<IdentifiedArrayOf<TranscriptionTask>> = LockIsolated([])
  private var cancellables: Set<AnyCancellable> = []

  private let executor: TranscriptionWorkExecutor

  init(executor: TranscriptionWorkExecutor) {
    self.executor = executor
    taskQueue.setValue(loadTasks())

    let notificationCenter = NotificationCenter.default

    notificationCenter.publisher(for: UIApplication.willResignActiveNotification).sink { [weak self] _ in
      guard let self, isProcessing else { return }
      beginBackgroundTask()
      scheduleBackgroundProcessingTask()
    }.store(in: &cancellables)

    notificationCenter.publisher(for: UIApplication.willEnterForegroundNotification).sink { [weak self] _ in
      guard let self else { return }
      endBackgroundTask()
      cancelScheduledBackgroundProcessingTask()
    }.store(in: &cancellables)

    $taskQueue.sink { [weak self] _ in
      self?.saveTasks()
    }.store(in: &cancellables)
  }

  func enqueueTask(_ task: TranscriptionTask) {
    _ = taskQueue.withValue { $0.append(task) }
    Task {
      await processTasks()
    }
  }

  func removeTask(with id: TranscriptionTask.ID) {
    taskQueue.withValue { $0[id: id] = nil }
  }

  func removeAllTasks() {
    taskQueue.withValue { $0.removeAll() }
  }

  func getAllTasks() -> IdentifiedArrayOf<TranscriptionTask> {
    taskQueue.value
  }

  func tasksStream() -> AsyncStream<IdentifiedArrayOf<TranscriptionTask>> {
    $taskQueue.map(\.value).values.eraseToStream()
  }

  func isProcessingStream() -> AsyncStream<Bool> {
    $isProcessing.values.eraseToStream()
  }

  func registerForProcessingTask() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
      self.handleBGProcessingTask(bgTask: task as! BGProcessingTask)
    }
  }

  private func processTasks() async {
    guard !isProcessing else { return }

    isProcessing = true

    while let task = taskQueue.first {
      currentTaskID = task.id
      await executor.processTask(task) { [weak self] newTask in
        self?.taskQueue.withValue { $0[id: task.id] = newTask }
      }
      taskQueue.withValue { $0[id: task.id] = nil }
      currentTaskID = nil
    }

    isProcessing = false
  }

  private func beginBackgroundTask() {
    backgroundTask = UIApplication.shared.beginBackgroundTask {
      self.endBackgroundTask()
    }
  }

  private func endBackgroundTask() {
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }

  private func scheduleBackgroundProcessingTask() {
    let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 1)

    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      log.error("Could not schedule background task: \(error)")
    }
  }

  private func cancelScheduledBackgroundProcessingTask() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: processingTaskIdentifier)
  }

  private func handleBGProcessingTask(bgTask: BGProcessingTask) {
    let task = Task {
      await processTasks()
    }

    bgTask.expirationHandler = {
      task.cancel()
    }
  }

  private func saveTasks() {
    UserDefaults.standard.encode(taskQueue.value, forKey: "taskQueue")
  }

  private func loadTasks() -> IdentifiedArrayOf<TranscriptionTask> {
    UserDefaults.standard.decode(forKey: "taskQueue") ?? []
  }
}
