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
  func processTasks() async
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
  @Published private var taskQueue: IdentifiedArrayOf<TranscriptionTask> = []
  private var cancellables: Set<AnyCancellable> = []

  private let executor: TranscriptionWorkExecutor

  init(executor: TranscriptionWorkExecutor) {
    self.executor = executor
    taskQueue = loadTasks()
    log.debug("Restored:", taskQueue)

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

    $taskQueue.sink { tasks in
      UserDefaults.standard.encode(tasks, forKey: "taskQueue")
    }.store(in: &cancellables)
  }

  func enqueueTask(_ task: TranscriptionTask) {
    Task {
      taskQueue.append(task)
      await processTasks()
    }
  }

  func processTasks() async {
    guard !isProcessing else { return }

    isProcessing = true

    while let task = taskQueue.first {
      currentTaskID = task.id
      await executor.processTask(task) { [weak self] newTask in
        self?.taskQueue[id: task.id] = newTask
      }
      taskQueue[id: task.id] = nil
      currentTaskID = nil
    }

    isProcessing = false
  }

  func removeTask(with id: TranscriptionTask.ID) {
    taskQueue[id: id] = nil
  }

  func removeAllTasks() {
    taskQueue.removeAll()
  }

  func getAllTasks() -> IdentifiedArrayOf<TranscriptionTask> {
    taskQueue
  }

  func tasksStream() -> AsyncStream<IdentifiedArrayOf<TranscriptionTask>> {
    $taskQueue.asAsyncStream()
  }

  func isProcessingStream() -> AsyncStream<Bool> {
    $isProcessing.asAsyncStream()
  }

  func registerForProcessingTask() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
      self.handleBGProcessingTask(bgTask: task as! BGProcessingTask)
    }
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

  private func loadTasks() -> IdentifiedArrayOf<TranscriptionTask> {
    UserDefaults.standard.decode(forKey: "taskQueue") ?? []
  }
}
