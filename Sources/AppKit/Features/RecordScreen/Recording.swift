import AudioProcessing
import Common
import ComposableArchitecture
import Dependencies
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
    @Shared var samples: [Float]
    var isLiveTranscription = false
    @Shared var liveTranscriptionState: LiveTranscriptionState
    @Shared var liveTranscriptionModelState: ModelLoadingStage

    @Presents var alert: AlertState<Action.Alert>?

    init(recordingInfo: RecordingInfo) {
      _recordingInfo = Shared(recordingInfo)
      _samples = Shared([])
      _liveTranscriptionState = Shared(.idle)
      _liveTranscriptionModelState = Shared(.idle)
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
    case alert(PresentationAction<Alert>)

    enum Delegate: Equatable {
      case didFinish(TaskResult<State>)
      case didCancel
    }

    enum Alert: Hashable {}
  }

  @Dependency(RecordingTranscriptionStream.self) var transcriptionStream: RecordingTranscriptionStream

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .delegate:
        return .none

      case let .startRecording(withLiveTranscription):
        state.mode = .recording
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        return .run { [state] _ in
          if withLiveTranscription {
            for try await liveState in try await transcriptionStream.startLiveTranscription(state.recordingInfo.fileURL) {
              switch liveState {
              case let .transcription(transcriptionState):
                state.$liveTranscriptionState.wrappedValue = .transcribing(transcriptionState.asCompleteTranscription)

                if state.$recordingInfo.wrappedValue.transcription == nil {
                  @Shared(.settings) var settings: Settings
                  state.$recordingInfo.wrappedValue.transcription = Transcription(
                    fileName: state.recordingInfo.fileName,
                    parameters: settings.parameters,
                    model: settings.selectedModel
                  )
                }

                let transcriptionSegments: [Segment] = transcriptionState.segments.map(\.asSimpleSegment)

                state.$recordingInfo.wrappedValue.transcription?.segments = transcriptionSegments
                state.$liveTranscriptionModelState.wrappedValue = transcriptionState.modelState
                  .asModelLoadingStage(progress: Double(transcriptionState.loadingProgressValue))

              case let .recording(recordingState):
                state.$recordingInfo.wrappedValue.duration = recordingState.duration
                state.$samples.wrappedValue = recordingState.waveSamples
              }
            }
          } else {
            for try await recordingState in try await transcriptionStream
              .startRecordingWithoutTranscription(state.recordingInfo.fileURL) {
              state.$recordingInfo.wrappedValue.duration = recordingState.duration
              state.$samples.wrappedValue = recordingState.waveSamples
            }
          }
        } catch: { error, send in
          logs.error("Error while starting recording: \(error)")
          await send(.delegate(.didFinish(.failure(error))))
        }

      case .saveButtonTapped:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.mode = .encoding

        return .run { [state] send in
          await transcriptionStream.stopRecording()
          await send(.delegate(.didFinish(.success(state))))
        }

      case .pauseButtonTapped:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.mode = .paused

        return .run { _ in
          await transcriptionStream.pauseRecording()
        }

      case .continueButtonTapped:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.mode = .recording

        return .run { _ in
          await transcriptionStream.resumeRecording()
        }

      case .deleteButtonTapped:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        state.mode = .removing

        return .run { [state] send in
          await transcriptionStream.stopRecording()
          try? FileManager.default.removeItem(at: state.recordingInfo.fileURL)
          await send(.delegate(.didCancel))
        }

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

extension TranscriptionSegment {
  var asSimpleSegment: Segment {
    Segment(
      startTime: Int64(start),
      endTime: Int64(end),
      text: text,
      tokens: tokens.enumerated().map { index, tokenID in
        Token(
          id: tokenID,
          index: index,
          data: TokenData(
            id: tokenID,
            tid: index,
            logProbability: tokenLogProbs.first?[tokenID] ?? 0
          ),
          speaker: nil
        )
      },
      speaker: nil
    )
  }
}
