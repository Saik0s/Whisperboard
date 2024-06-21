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
  }

  static let backgroundTaskIdentifier = "me.igortarasenko.Whisperboard"

  enum CancelID: Hashable { case processing }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .processTasks:
        guard !state.isProcessing else { return .none }

        if let task = await getNextTask(state: state) {
          return .run(priority: .background) { [state] send in
            await send(.setCurrentTask(task.task))
            await send(.beginBackgroundTask)
            await send(.scheduleBackgroundProcessingTask)
            await process(task: task)
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

        let isCurrent = task.map { task in executor.currentTaskID == task.id } ?? false
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

  func process(task: TranscriptionTaskEnvelope) async {
    let taskId = await MainActor.run { task.id }
    logs.debug("Starting transcription process for task ID: \(taskId)")
    defer {
      logs.debug("Ending transcription process for task ID: \(taskId)")
    }

    DispatchQueue.main.async {
      if task.recording.transcription?.id != taskId {
        logs.debug("Initializing new transcription for task ID: \(taskId)")
        task.recording.transcription = Transcription(id: taskId, fileName: task.fileName, parameters: task.parameters, model: task.modelType)
      }
    }

    do {
      DispatchQueue.main.async {
        logs.debug("Setting transcription status to loading for task ID: \(taskId)")
        task.recording.transcription?.status = .loading
      }

      let model = await task.modelType

      // MARK: Load model

      let computeOptions = ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine)
      let whisperKit = try await WhisperKit(model: model, computeOptions: computeOptions, load: true)

      logs.debug("Model (\(model)) loaded for task ID \(taskId)")

      DispatchQueue.main.async {
        logs.debug("Setting transcription status to progress for task ID: \(taskId)")
        task.recording.transcription?.status = .progress(task.progress, text: "")
      }

      // MARK: Load audio file

      let fileURL = await task.recording.fileURL
      logs.debug("File URL for task ID \(taskId): \(fileURL)")

      let audioBuffer = try AudioProcessor.loadAudio(fromPath: fileURL.path())
      let audioArray = AudioProcessor.convertBufferToArray(buffer: audioBuffer)

      var results: [TranscriptionResult?] = []
      var prevResult: TranscriptionResult?
      var lastAgreedSeconds: Float = 0.0
      let agreementCountNeeded = 2
      var hypothesisWords: [WordTiming] = []
      var prevWords: [WordTiming] = []
      var lastAgreedWords: [WordTiming] = []
      var confirmedWords: [WordTiming] = []

      let options = DecodingOptions(task: .transcribe, skipSpecialTokens: true, wordTimestamps: false, suppressBlank: true)

      //      for seekSample in stride(from: 16000, to: audioArray.count, by: 16000) {
      //      let endSample = min(seekSample + 16000, audioArray.count)
      //      let simulatedStreamingAudio = Array(audioArray[..<endSample])
      if true {
        //        let seekSample = 0
        //        let endSample = audioArray.count
        let simulatedStreamingAudio = audioArray

        var streamOptions = options
        streamOptions.clipTimestamps = [lastAgreedSeconds]
        let lastAgreedTokens = lastAgreedWords.flatMap(\.tokens)
        streamOptions.prefixTokens = lastAgreedTokens
        do {
          let result: TranscriptionResult? = try await whisperKit.transcribe(
            audioArray: simulatedStreamingAudio,
            decodeOptions: streamOptions,
            callback: { progress in
              DispatchQueue.main.async {
                task.recording.transcription?.status = .progress(whisperKit.progress.fractionCompleted, text: progress.text)
              }
              return true
            }
          ).first
          var skipAppend = false
          if let result, let _ = result.segments.first?.words {
            hypothesisWords = result.allWords.filter { $0.start >= lastAgreedSeconds }

            if let prevResult {
              prevWords = prevResult.allWords.filter { $0.start >= lastAgreedSeconds }
              let commonPrefix = findLongestCommonPrefix(prevWords, hypothesisWords)

              if commonPrefix.count >= agreementCountNeeded {
                lastAgreedWords = commonPrefix.suffix(agreementCountNeeded)
                lastAgreedSeconds = lastAgreedWords.first!.start

                confirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - agreementCountNeeded))
              } else {
                skipAppend = true
              }
            }
            prevResult = result
          }
          if !skipAppend {
            results.append(result)
          }
        } catch {
          logs.debug("Error: \(error.localizedDescription)")
        }
      }

      // MARK: Merge results

      let finalWords = lastAgreedWords + findLongestDifferentSuffix(prevWords, hypothesisWords)
      confirmedWords.append(contentsOf: finalWords)

      let mergedResult = mergeTranscriptionResults(results, confirmedWords: confirmedWords)

      DispatchQueue.main.async {
        logs.debug("Setting transcription status to done for task ID: \(taskId)")
        task.recording.transcription?.segments = mergedResult.segments.map(\.asSimpleSegment)
        task.recording.transcription?.text = mergedResult.text
        task.recording.transcription?.status = .done(Date())
      }
    } catch {
      DispatchQueue.main.async {
        logs.error("Error during transcription for task ID \(taskId): \(error.localizedDescription)")
        task.recording.transcription?.status = .error(message: error.localizedDescription)
      }
    }
  }
}
