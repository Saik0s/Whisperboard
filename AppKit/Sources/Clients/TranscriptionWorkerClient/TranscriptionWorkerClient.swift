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
        worker.$taskQueue.wrappedValue.append(task)
        await worker.processTasks()
      },
      cancelTaskForRecordingID: { [worker] id in
        if let task = await worker.currentTask, task.recordingInfoID == id {
          localWorkExecutor.cancelTask(id: task.id)
        }
        worker.$taskQueue.wrappedValue.removeAll { task in
          task.recordingInfoID == id
        }
      },
      cancelAllTasks: { [worker] in
        if let task = await worker.currentTask {
          localWorkExecutor.cancelTask(id: task.id)
        }
        worker.$taskQueue.wrappedValue.removeAll()
      },
      handleBGProcessingTask: { task in
        worker.handleBGProcessingTask(bgTask: task)
      },
      getAvailableLanguages: {
        [.auto] + WhisperContext.getAvailableLanguages()
      },
      resumeTask: { [worker] task in
        if let index = worker.$taskQueue.wrappedValue.firstIndex(where: { $0.id == task.id }) {
          worker.$taskQueue.wrappedValue[index] = task
        } else {
          worker.$taskQueue.wrappedValue.insert(task, at: 0)
        }
        await worker.processTasks(ignorePaused: false)
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

  @MainActor @Shared(.isProcessing) var isProcessing: Bool
  @MainActor @Shared(.transcriptionTasks) var taskQueue: [TranscriptionTask]
  @MainActor @Shared(.recordings) var recordings: [RecordingInfo]

  private let executor: TranscriptionWorkExecutor

  @MainActor var currentTask: TranscriptionTask? { isProcessing ? taskQueue.first : nil }

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
  func processTasks(ignorePaused: Bool = true) {
    guard !isProcessing, !taskQueue.isEmpty else { return }

    isProcessing = true

    task = Task(priority: .background) { [weak self] in
      guard let self else { return }
      defer { isProcessing = false }

      while let task = $taskQueue.elements.filter({ ignorePaused ? !$0.isPaused.wrappedValue : true }).first {
        if let recording = $recordings.elements.first(where: { $0.id == task.recordingInfoID }) {
          let envelope = TranscriptionTaskEnvelope(task: task, recording: recording)
          await executor.process(task: envelope)
        } else {
          logs.error("Recording not found for task \(task.id), recordingId \(task.recordingInfoID)")
        }
        taskQueue.removeAll { $0.id == task.id }
      }
    }
  }

  func handleBGProcessingTask(bgTask: BGProcessingTask) {
    Task { @MainActor in
      processTasks(ignorePaused: false)
    }

    bgTask.expirationHandler = { [weak self] in
      self?.task?.cancel()
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
