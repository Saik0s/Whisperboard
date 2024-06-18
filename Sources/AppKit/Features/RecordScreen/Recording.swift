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

      var modelProgress: Double? {
        if case let .modelLoading(progress) = self {
          return progress
        }
        return nil
      }

      var currentText: String? {
        if case let .transcribing(text) = self {
          return text
        }
        return nil
      }
    }

    var mode: Mode = .recording

    @Shared var recordingInfo: RecordingInfo
    @Shared var samples: [Float]
    @Shared var liveTranscriptionState: LiveTranscriptionState?

    init(recordingInfo: RecordingInfo) {
      _recordingInfo = Shared(recordingInfo)
      _samples = Shared([])
      _liveTranscriptionState = Shared(nil)
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case startRecording
    case saveButtonTapped
    case pauseButtonTapped
    case continueButtonTapped
    case deleteButtonTapped

    enum Delegate: Equatable {
      case didFinish(TaskResult<State>)
      case didCancel
    }
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

      case .startRecording:
        state.mode = .recording

        return .run { [liveTranscriptionState = state.$liveTranscriptionState, recordingInfo = state.$recordingInfo, state] _ in
          generateImpact()

          for try await transcriptionState in await transcriptionStream.startLiveTranscription() {
            liveTranscriptionState.withLock { liveTranscriptionState in
              if transcriptionState.modelState != .loaded {
                liveTranscriptionState = .modelLoading(Double(transcriptionState.loadingProgressValue))
              } else {
                liveTranscriptionState = .transcribing(transcriptionState.currentText)
              }
            }

            if recordingInfo.wrappedValue.transcription == nil {
              recordingInfo.withLock { recordingInfo in
                @Shared(.settings) var settings: Settings
                recordingInfo.transcription = Transcription(
                  fileName: recordingInfo.fileName,
                  parameters: settings.parameters,
                  model: settings.selectedModelName
                )
              }
            }

            let transcriptionSegments: [Segment] = transcriptionState.segments.map(\.asSimpleSegment)
            state.$recordingInfo.withLock { recordingInfo in
              recordingInfo.transcription?.segments = transcriptionSegments
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
      }
    }
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
      text: text.trimmingCharacters(in: .whitespacesAndNewlines),
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
