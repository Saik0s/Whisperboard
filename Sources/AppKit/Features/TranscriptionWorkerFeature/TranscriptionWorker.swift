import AsyncAlgorithms
import BackgroundTasks
import Combine
import Common
import ComposableArchitecture
import Dependencies
import IdentifiedCollections
import UIKit
import WhisperKit

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
    case transcriptionDidUpdate(Transcription, task: TranscriptionTask)
  }

  static let backgroundTaskIdentifier = "me.igortarasenko.Whisperboard"

  enum CancelID: Hashable { case processing }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .processTasks:
        guard !state.isProcessing else { return .none }

        if let (task, recording) = getNextTask(state: state) {
          return .run { send in
            await send(.setCurrentTask(task))
            await send(.beginBackgroundTask)
            await send(.scheduleBackgroundProcessingTask)
            await process(task: task, recording: recording) { transcription in
              await send(.transcriptionDidUpdate(transcription, task: task))
            }
            await send(.endBackgroundTask)
            await send(.cancelScheduledBackgroundProcessingTask)
            // TODO: Make sure it is handled properly in case of canceling
            await send(.currentTaskFinishProcessing)
          }.cancellable(id: CancelID.processing, cancelInFlight: true)
        } else {
          return .none
        }

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
        let task = state.taskQueue.first { task in
          task.recordingInfoID == id
        }

        let isCurrent = state.currentTask?.id == task?.id && task != nil
        state.taskQueue.removeAll { $0.recordingInfoID == id }

        return isCurrent ? .cancel(id: CancelID.processing) : .none

      case .cancelAllTasks:
        state.taskQueue.removeAll()
        return .cancel(id: CancelID.processing)

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

      case let .transcriptionDidUpdate(transcription, task: task):
        if let recordingIndex = state.recordings.firstIndex(where: { $0.id == task.recordingInfoID }) {
          state.recordings[recordingIndex].transcription = transcription
        }
        return .none
      }
    }
  }

  private func getNextTask(state: State) -> (task: TranscriptionTask, recording: RecordingInfo)? {
    while let task = state.taskQueue.first {
      if let recording = state.recordings.first(where: { $0.id == task.recordingInfoID }) {
        return (task: task, recording: recording)
      }
      state.taskQueue.removeFirst()
    }
    return nil
  }

  func process(task: TranscriptionTask, recording: RecordingInfo, callback: @escaping (Transcription) async -> Void) async {
    logs.debug("Starting transcription process for task ID: \(task.id)")
    defer {
      logs.debug("Ending transcription process for task ID: \(task.id)")
    }

    let model = task.settings.selectedModelName

    let transcription = LockIsolated(Transcription(
      id: task.id,
      fileName: recording.fileName,
      parameters: task.settings.parameters,
      model: model
    ))

    let updateClosure: ((inout Transcription) -> Void) -> Void = { update in
      transcription.withValue { transcription in
        update(&transcription)
      }
      Task { @MainActor in
        await callback(transcription.value)
      }
    }

    let fileURL = recording.fileURL
    logs.debug("File URL for task ID \(task.id): \(fileURL)")

    do {
      logs.debug("Setting transcription status to loading for task ID: \(task.id)")
      updateClosure { $0.status = .loading }

      // MARK: Load model

      let computeOptions = ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine)
      let whisperKit = try await WhisperKit(model: model, computeOptions: computeOptions, load: true)

      logs.debug("Model (\(model)) loaded for task ID \(task.id)")

      // MARK: Transcription

      updateClosure { $0.status = .progress(0, text: "") }

      let options = DecodingOptions(task: .transcribe, skipSpecialTokens: true, wordTimestamps: false, suppressBlank: true)

      let results: [TranscriptionResult] = try await whisperKit.transcribe(
        audioPath: fileURL.path(),
        decodeOptions: options,
        callback: { progress in
          updateClosure { transcription in
            transcription.status = .progress(whisperKit.progress.fractionCompleted, text: progress.text)
          }
          return true
        }
      )

      let mergedResult = mergeTranscriptionResults(results)

      logs.debug("Setting transcription status to done for task ID: \(task.id)")
      updateClosure { transcription in
        transcription.segments = mergedResult.segments.map(\.asSimpleSegment)
        transcription.text = mergedResult.text
        transcription.status = .done(Date())
      }
    } catch {
      logs.error("Error during transcription for task ID \(task.id): \(error.localizedDescription)")
      updateClosure { transcription in
        transcription.status = .error(message: error.localizedDescription)
      }
    }
  }
}
