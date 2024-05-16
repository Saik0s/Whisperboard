import ComposableArchitecture
import SwiftUI
import WhisperKit

// MARK: - Recording

@Reducer
struct Recording {
  @ObservableState
  struct State: Equatable {
    enum Mode: Equatable {
      case recording, encoding, paused, removing
    }

    enum LiveTranscriptionState: Equatable {
      case idle, loading(String), transcribing(String), error(String)
    }

    @Shared var recordingInfo: RecordingInfo
    var mode: Mode = .recording
    var samples: [Float] = []
    var isLiveTranscription = false
    var liveTranscriptionState: LiveTranscriptionState = .idle
    var liveTranscriptionModelState: ModelLoadingStage = .loading

    @Presents var alert: AlertState<Action.Alert>?

    init(recordingInfo: RecordingInfo) {
      _recordingInfo = Shared(recordingInfo)
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case startRecording(withLiveTranscription: Bool)
    case saveButtonTapped
    case pauseButtonTapped
    case continueButtonTapped
    case deleteButtonTapped
    case transcriptionStateUpdated(AudioFileStreamRecorder.State)
    case modelStateUpdated(ModelLoadingStage)
    case alert(PresentationAction<Alert>)

    enum Delegate: Equatable {
      case didFinish(TaskResult<State>)
      case didCancel
    }

    enum Alert: Hashable {
      case error(String)
    }
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder

  @Dependency(RecordingTranscriptionStream.self) var recordingTranscriptionStream

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .startRecording(withLiveTranscription):
        state.mode = .recording
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        return .run { [url = state.recordingInfo.fileURL, recordingTranscriptionStream] send in
          if withLiveTranscription {
            try await withThrowingTaskGroup(of: Void.self) { group in
              group.addTask {
                for try await modelState in try await recordingTranscriptionStream.loadModel("base") {
                  await send(.modelStateUpdated(modelState), animation: .bouncy)
                }
              }

              group.addTask {
                for try await transcriptionState in try await recordingTranscriptionStream.startLiveTranscription(url) {
                  await send(.transcriptionStateUpdated(transcriptionState), animation: .bouncy)
                }
              }

              try await group.waitForAll()
            }

            try await recordingTranscriptionStream.unloadModel()
            await send(.modelStateUpdated(.loading), animation: .bouncy)
          } else {
            for try await transcriptionState in await recordingTranscriptionStream.startRecordingWithoutTranscription(url) {
              await send(.transcriptionStateUpdated(transcriptionState), animation: .bouncy)
            }
          }
        } catch: { error, send in
          await send(.alert(.presented(.error(error.localizedDescription))))
          await send(.delegate(.didFinish(.failure(error))))
        }

      case .delegate:
        return .none

      case .saveButtonTapped:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.mode = .encoding

        return .run { [recordingTranscriptionStream, state] send in
          await recordingTranscriptionStream.stopRecording()
          await send(.delegate(.didFinish(.success(state))))
        }

      case .pauseButtonTapped:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.mode = .paused

        return .run { [recordingTranscriptionStream] _ in
          await recordingTranscriptionStream.pauseRecording()
        }

      case .continueButtonTapped:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.mode = .recording

        return .run { [recordingTranscriptionStream] _ in
          await recordingTranscriptionStream.resumeRecording()
        }

      case .deleteButtonTapped:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.mode = .removing

        return .run { [recordingTranscriptionStream, state] send in
          await recordingTranscriptionStream.stopRecording()
          try? FileManager.default.removeItem(at: state.recordingInfo.fileURL)
          await send(.delegate(.didCancel))
        }

      case let .transcriptionStateUpdated(transcriptionState):
        let confirmedText = transcriptionState.confirmedSegments
          .map { "- \($0.text)" }
          .joined(separator: "\n")

        let unconfirmedText = transcriptionState.unconfirmedSegments
          .map { segment in
            """
            - ID: \(segment.id)
              Seek: \(segment.seek)
              Start: \(segment.start)
              End: \(segment.end)
              Text: \(segment.text)
            """
          }
          .joined(separator: "\n")

        let completeTranscription = """
        currentFallbacks: \(transcriptionState.currentFallbacks)
        lastBufferSize: \(transcriptionState.lastBufferSize)
        lastConfirmedSegmentEndSeconds: \(transcriptionState.lastConfirmedSegmentEndSeconds)
        ---
        Confirmed:
        \(confirmedText)
        Unconfirmed:
        \(unconfirmedText)
        """
        state.liveTranscriptionState = .transcribing(completeTranscription)

        if state.recordingInfo.transcription == nil {
          @Shared(.settings) var settings: Settings
          state.recordingInfo.transcription = Transcription(
            id: UUID(),
            fileName: state.recordingInfo.fileName,
            parameters: settings.parameters,
            model: settings.selectedModel
          )
        }

        let rawSegments = transcriptionState.confirmedSegments + transcriptionState.unconfirmedSegments
        let transcriptionSegments: [Segment] = rawSegments.map { segment in
          Segment(
            startTime: Int64(segment.start),
            endTime: Int64(segment.end),
            text: segment.text,
            tokens: segment.tokens.enumerated().map { index, tokenID in
              Token(
                id: Int32(tokenID),
                index: Int32(index),
                text: recordingTranscriptionStream.tokenIDToToken(tokenID),
                data: TokenData(
                  id: tokenID,
                  tid: index,
                  probability: segment.tokenLogProbs.first?[tokenID] ?? 0,
                  logProbability: 0,
                  timestampProbability: 0,
                  sumTimestampProbabilities: 0,
                  startTime: 0,
                  endTime: 0,
                  voiceLength: 0
                ),
                speaker: nil
              )
            },
            speaker: nil
          )
        }

        state.recordingInfo.transcription?.segments = transcriptionSegments
        state.samples = transcriptionState.waveSamples
        state.recordingInfo.duration = transcriptionState.duration
        return .none

      case let .modelStateUpdated(modelState):
        state.liveTranscriptionModelState = modelState
        return .none

      case let .alert(.presented(.error(message))):
        state.alert = AlertState {
          TextState("Error")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("OK")
          }
        } message: {
          TextState(message)
        }
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
