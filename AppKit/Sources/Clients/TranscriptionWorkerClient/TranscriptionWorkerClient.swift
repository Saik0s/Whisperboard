import AsyncAlgorithms
import BackgroundTasks
import Combine
import ComposableArchitecture
import Dependencies
import IdentifiedCollections
import UIKit

// MARK: - TranscriptionWorkerClient

@DependencyClient
struct TranscriptionWorkerClient {
  var enqueueTaskForRecordingID: @Sendable (_ id: RecordingInfo.ID, _ settings: Settings) async -> Void
  var cancelTaskForRecordingID: @Sendable (_ id: RecordingInfo.ID) async -> Void
  var cancelAllTasks: @Sendable () async -> Void
  var handleBGProcessingTask: @Sendable (_ bgTask: BGProcessingTask) -> Void
  var getAvailableLanguages: @Sendable () -> [VoiceLanguage] = { [] }
  var resumeTask: @Sendable (_ task: TranscriptionTask) async -> Void
}

// MARK: DependencyKey

extension TranscriptionWorkerClient: DependencyKey {
  static let liveValue: TranscriptionWorkerClient = {
    let localWorkExecutor = LocalTranscriptionWorkExecutor()
    let worker = TranscriptionWorker(executor: localWorkExecutor)

    return TranscriptionWorkerClient(
      enqueueTaskForRecordingID: { [worker] id, settings in
        let task = TranscriptionTask(recordingInfoID: id, settings: settings)
        await MainActor.run { worker.taskQueue.append(task) }
        await worker.processTasks()
      },
      cancelTaskForRecordingID: { [worker] id in
        if let task = worker.currentTask, task.recordingInfoID == id {
          localWorkExecutor.cancelTask(id: task.id)
        }
        await MainActor.run { worker.taskQueue.removeAll { $0.recordingInfoID == id } }
      },
      cancelAllTasks: { [worker] in
        localWorkExecutor.cancelCurrentTask()
        await MainActor.run { worker.taskQueue.removeAll() }
      },
      handleBGProcessingTask: { task in
        worker.handleBGProcessingTask(bgTask: task)
      },
      getAvailableLanguages: {
        [.auto] + WhisperContext.getAvailableLanguages()
      },
      resumeTask: { [worker] task in
        await MainActor.run { worker.taskQueue.append(task) }
        await worker.processTasks()
      }
    )
  }()
}

extension DependencyValues {
  var transcriptionWorker: TranscriptionWorkerClient {
    get { self[TranscriptionWorkerClient.self] }
    set { self[TranscriptionWorkerClient.self] = newValue }
  }
}

// MARK: - TranscriptionWorker

class TranscriptionWorker {
  static let processingTaskIdentifier = "me.igortarasenko.Whisperboard"

  var currentTask: TranscriptionTask?

  @MainActor @Shared(.isProcessing) var isProcessing: Bool
  @MainActor @Shared(.transcriptionTasks) var taskQueue: [TranscriptionTask]
  @MainActor @Shared(.recordings) var recordings: [RecordingInfo]

  private let executor: TranscriptionWorkExecutor

  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var cancellables: Set<AnyCancellable> = []
  private var task: Task<Void, Never>?

  init(executor: TranscriptionWorkExecutor) {
    self.executor = executor

    NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).sink { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        guard self.isProcessing else { return }
        self.beginBackgroundTask()
        self.scheduleBackgroundProcessingTask()
      }
    }.store(in: &cancellables)

    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification).sink { [weak self] _ in
      guard let self else { return }
      endBackgroundTask()
      cancelScheduledBackgroundProcessingTask()
    }.store(in: &cancellables)
  }

  @MainActor
  func processTasks() {
    task = Task(priority: .background) { [weak self] in
      guard let self, !isProcessing else { return }
      isProcessing = true
      defer { isProcessing = false }

      while let task = await getNextTask() {
        currentTask = task.task
        await executor.process(task: task)
        currentTask = nil
        taskQueue[id: task.task.id] = nil
      }
    }
  }

  func handleBGProcessingTask(bgTask: BGProcessingTask) {
    Task { @MainActor in
      processTasks()
    }

    bgTask.expirationHandler = { [weak self] in
      self?.task?.cancel()
    }
  }

  @MainActor
  private func getNextTask() async -> TranscriptionTaskEnvelope? {
    taskQueue = taskQueue.filter { task in
      recordings.contains { $0.id == task.recordingInfoID }
    }
    return $taskQueue.elements.compactMap { task in
      $recordings.elements
        .first { $0.id == task.recordingInfoID }
        .map { TranscriptionTaskEnvelope(task: task, recording: $0) }
    }.first
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
    let request = BGProcessingTaskRequest(identifier: TranscriptionWorker.processingTaskIdentifier)
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 1)

    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      logs.error("Could not schedule background task: \(error)")
    }
  }

  private func cancelScheduledBackgroundProcessingTask() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: TranscriptionWorker.processingTaskIdentifier)
  }
}
