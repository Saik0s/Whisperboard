import AudioProcessing
import Common
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
    @Shared var samples: [Float]
    var isLiveTranscription = false
    @Shared var liveTranscriptionState: LiveTranscriptionState
    @Shared var liveTranscriptionModelState: ModelLoadingStage

    @Presents var alert: AlertState<Action.Alert>?

    init(recordingInfo: RecordingInfo) {
      _recordingInfo = Shared(recordingInfo)
      _samples = Shared([])
      _liveTranscriptionState = Shared(.idle)
      _liveTranscriptionModelState = Shared(.loading)
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

  @Dependency(RecordingTranscriptionStream.self) var recordingTranscriptionStream

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
            for try await liveState in try await recordingTranscriptionStream.startLiveTranscription(state.recordingInfo.fileURL) {
              switch liveState {
              case let .transcription(transcriptionState):
                let confirmedText = transcriptionState.confirmedSegments
                  .map { "- \($0.text)" }
                  .joined()

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
                  .joined()

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
                state.$liveTranscriptionState.wrappedValue = .transcribing(completeTranscription)

                if state.$recordingInfo.wrappedValue.transcription == nil {
                  @Shared(.settings) var settings: Settings
                  state.$recordingInfo.wrappedValue.transcription = Transcription(
                    id: UUID(),
                    fileName: state.recordingInfo.fileName,
                    parameters: settings.parameters,
                    model: settings.selectedModel ?? recordingTranscriptionStream.defaultModel
                  )
                }

                let rawSegments = transcriptionState.confirmedSegments + transcriptionState.unconfirmedSegments
                let transcriptionSegments: [Segment] = rawSegments.map(\.asSimpleSegment)

                state.recordingInfo.wrappedValue.transcription?.segments = transcriptionSegments
                state.liveTranscriptionModelState.wrappedValue = transcriptionState.modelState.asModelLoadingStage(progress: state.loadingProgressValue)

              case let .recording(recordingState):
                state.recordingInfo.wrappedValue.duration = recordingState.duration
                state.samples.wrappedValue = recordingState.waveSamples
              }
            }
          } else {
            for try await recordingState in try await recordingTranscriptionStream
              .startRecordingWithoutTranscription(fileURL: state.recordingInfo.fileURL) {
              state.recordingInfo.wrappedValue.duration = recordingState.duration
              state.samples.wrappedValue = recordingState.waveSamples
            }
          }
        } catch: { error, send in
          logs.error("Error while starting recording: \(error)")
          await send(.delegate(.didFinish(.failure(error))))
        }

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
