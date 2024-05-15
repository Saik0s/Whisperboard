import AsyncAlgorithms
import BackgroundTasks
import Combine
import ComposableArchitecture
import Dependencies
import IdentifiedCollections
import UIKit

// MARK: - TranscriptionWorkerClient

@Reducer
struct TranscriptionWorker: Reducer {
  @ObservableState
  struct State: Equatable {
    @Shared(.transcriptionTasks) var taskQueue: [TranscriptionTask] = []
    @Shared(.recordings) var recordings: [RecordingInfo] = []
    fileprivate var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var isProcessing: Bool {
      currentTask != nil
    }

    var currentTask: TranscriptionTask?
  }

  enum Action {
    case task
    case processTasks
    case handleBGProcessingTask(BGProcessingTask)
    case beginBackgroundTask
    case endBackgroundTask
    case scheduleBackgroundProcessingTask
    case cancelScheduledBackgroundProcessingTask
    case enqueueTaskForRecordingID(RecordingInfo.ID, Settings)
    case cancelTaskForRecordingID(RecordingInfo.ID)
    case cancelAllTasks
    case resumeTask(TranscriptionTask)
    case setCurrentTask(TranscriptionTask)
    case currentTaskFinishProcessing
    case setBackgroundTask(UIBackgroundTaskIdentifier) // Added this case
  }

  static let backgroundTaskIdentifier = "me.igortarasenko.Whisperboard"

  @Dependency(\.localTranscriptionWorkExecutor) var executor: TranscriptionWorkExecutor
  @Dependency(\.didEnterBackground) var didEnterBackground: @Sendable () async -> AsyncStream<Void>
  @Dependency(\.willEnterForeground) var willEnterForeground: @Sendable () async -> AsyncStream<Void>

  enum CancelID: Hashable { case processing }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        return .none

      case .processTasks:
        guard !state.isProcessing else { return .none }

        return .run(priority: .background) { [state] send in
          if let task = await getNextTask(state: state) {
            await send(.setCurrentTask(task.task))
            await send(.beginBackgroundTask)
            await send(.scheduleBackgroundProcessingTask)
            await executor.process(task: task)
            await send(.endBackgroundTask)
            await send(.cancelScheduledBackgroundProcessingTask)
            await send(.currentTaskFinishProcessing)
          }
        }.cancellable(id: CancelID.processing, cancelInFlight: true)

      case let .handleBGProcessingTask(bgTask):
        return .run { send in
          bgTask.expirationHandler = {}
          await send(.processTasks)
        }

      case .beginBackgroundTask:
        guard state.isProcessing else { return .none }
        return .run { send in
          let taskIdentifier = await UIApplication.shared.beginBackgroundTask {
            Task { await send(.endBackgroundTask) }
          }
          await send(.setBackgroundTask(taskIdentifier))
        }

      case .endBackgroundTask:
        return .send(.setBackgroundTask(.invalid))

      case let .setBackgroundTask(taskIdentifier):
        if state.backgroundTask != .invalid {
          UIApplication.shared.endBackgroundTask(state.backgroundTask)
        }
        state.backgroundTask = taskIdentifier
        return .none

      case .scheduleBackgroundProcessingTask:
        guard state.isProcessing else { return .none }
        let request = BGProcessingTaskRequest(identifier: TranscriptionWorker.backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)

        do {
          try BGTaskScheduler.shared.submit(request)
        } catch {
          logs.error("Could not schedule background task: \(error)")
        }
        return .none

      case .cancelScheduledBackgroundProcessingTask:
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: TranscriptionWorker.backgroundTaskIdentifier)
        return .none

      case let .enqueueTaskForRecordingID(id, settings):
        let task = TranscriptionTask(recordingInfoID: id, settings: settings)
        state.taskQueue.append(task)
        return .send(.processTasks)

      case let .cancelTaskForRecordingID(id):
        if let task = state.taskQueue.first(where: { $0.recordingInfoID == id }) {
          executor.cancelTask(id: task.id)
        }
        state.taskQueue.removeAll { $0.recordingInfoID == id }
        return .none

      case .cancelAllTasks:
        if let currentTaskID = state.currentTask?.id {
          executor.cancelTask(id: currentTaskID)
        }
        state.taskQueue.removeAll()
        return .none

      case let .resumeTask(task):
        state.taskQueue.insert(task, at: 0)
        return .send(.processTasks)

      case let .setCurrentTask(task):
        state.currentTask = task
        return .none

      case .currentTaskFinishProcessing:
        if let currentTask = state.currentTask {
          state.taskQueue.removeAll { $0.id == currentTask.id }
        }
        state.currentTask = nil
        return .run { send in
          await send(.processTasks) // Send processTasks action again after finishing the current task
        }
      }
    }
  }

  @MainActor
  private func getNextTask(state: State) async -> TranscriptionTaskEnvelope? {
    let filteredQueue = state.$taskQueue.elements.filter { task in
      state.recordings.contains { $0.id == task.wrappedValue.recordingInfoID }
    }
    return filteredQueue.compactMap { task in
      state.$recordings.elements
        .first { $0.id == task.recordingInfoID }
        .map { TranscriptionTaskEnvelope(task: task, recording: $0) }
    }.first
  }
}
