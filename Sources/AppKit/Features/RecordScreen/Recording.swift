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
      case recording, saving, paused, removing
    }

    enum LiveTranscriptionState: Equatable {
      case modelLoading(Double), transcribing(String)
    }

    var mode: Mode = .recording
    var isLiveTranscription = false

    @Shared var recordingInfo: RecordingInfo
    @Shared var samples: [Float]
    @Shared var liveTranscriptionState: LiveTranscriptionState?

    @Presents var alert: AlertState<Action.Alert>?

    init(recordingInfo: RecordingInfo) {
      _recordingInfo = Shared(recordingInfo)
      _samples = Shared([])
      _liveTranscriptionState = Shared(nil)
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

        return .run { [state] _ in
          let fileURL = state.recordingInfo.fileURL

          generateImpact()
          if withLiveTranscription {
            for try await liveState in try await transcriptionStream.startLiveTranscription(fileURL) {
              switch liveState {
              case let .transcription(transcriptionState):
                if transcriptionState.modelState != .loaded {
                  state.$liveTranscriptionState.wrappedValue = .modelLoading(Double(transcriptionState.loadingProgressValue))
                } else {
                  state.$liveTranscriptionState.wrappedValue = .transcribing(transcriptionState.currentText)
                }

                if state.$recordingInfo.wrappedValue.transcription == nil {
                  @Shared(.settings) var settings: Settings
                  state.$recordingInfo.wrappedValue.transcription = Transcription(
                    fileName: state.$recordingInfo.wrappedValue.fileName,
                    parameters: settings.parameters,
                    model: settings.selectedModelName
                  )
                }

                let transcriptionSegments: [Segment] = transcriptionState.segments.map(\.asSimpleSegment)

                state.$recordingInfo.wrappedValue.transcription?.segments = transcriptionSegments

              case let .recording(recordingState):
                state.$recordingInfo.wrappedValue.duration = recordingState.duration
                state.$samples.wrappedValue = recordingState.waveSamples
              }
            }
          } else {
            for try await recordingState in try await transcriptionStream.startRecordingWithoutTranscription(fileURL) {
              state.$recordingInfo.wrappedValue.duration = recordingState.duration
              state.$samples.wrappedValue = recordingState.waveSamples
            }
          }
        } catch: { error, send in
          logs.error("Error while starting recording: \(error)")
          await send(.delegate(.didFinish(.failure(error))))
        }

      case .saveButtonTapped:
        state.mode = .saving

        return .run { [state] send in
          generateImpact()
          await transcriptionStream.stopRecording()
          await send(.delegate(.didFinish(.success(state))))
        }

      case .pauseButtonTapped:
        state.mode = .paused

        return .run { _ in
          generateImpact()
          await transcriptionStream.pauseRecording()
        }

      case .continueButtonTapped:
        state.mode = .recording

        return .run { _ in
          generateImpact()
          await transcriptionStream.resumeRecording()
        }

      case .deleteButtonTapped:
        state.mode = .removing

        return .run { [state] send in
          generateImpact()
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

  func generateImpact() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
