import AudioProcessing
import Common
import ComposableArchitecture
import Dependencies
import DSWaveformImage
import DSWaveformImageViews
import Foundation
import Inject
import Popovers
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
    var isModelLoadingInfoPresented = false

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
    case onTask
    case saveButtonTapped
    case pauseButtonTapped
    case continueButtonTapped
    case deleteButtonTapped
    case toggleModelLoadingInfo

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

      case .onTask:
        state.mode = .recording

        return .run { [
          liveTranscriptionState = state.$liveTranscriptionState,
          recordingInfo = state.$recordingInfo,
          samples = state.$samples
        ] _ in
          generateImpact()

          try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
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
                recordingInfo.withLock { recordingInfo in
                  recordingInfo.transcription?.segments = transcriptionSegments
                }
              }
            }

            group.addTask {
              for try await recordingState in await transcriptionStream.startRecording(recordingInfo.wrappedValue.fileURL) {
                samples.withLock  { samples in
                  samples = recordingState.waveSamples
                }
              }
            }

            try await group.waitForAll()
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

      case .toggleModelLoadingInfo:
        state.isModelLoadingInfoPresented.toggle()
        return .none
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

// MARK: - RecordingView

/// A view that displays the recording waveform and current time.
struct RecordingView: View {
  @Perception.Bindable var store: StoreOf<Recording>

  var currentTime: String {
    dateComponentsFormatter.string(from: store.recordingInfo.duration) ?? ""
  }

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(3)) {
        liveTranscriptionView()

        WaveformLiveCanvas(samples: store.state.samples, configuration: Waveform.Configuration(
          backgroundColor: .clear,
          style: .striped(.init(color: UIColor(Color.DS.Text.base), width: 2, spacing: 4, lineCap: .round)),
          damping: .init(percentage: 0.125, sides: .both),
          scale: DSScreen.scale,
          verticalScalingFactor: 0.95,
          shouldAntialias: true
        ))
        .frame(maxWidth: .infinity)

        Text(currentTime)
          .foregroundColor(.DS.Text.accent)
          .textStyle(.navigationTitle)
          .monospaced()
      }
    }
    .task {
      await store.send(.onTask).finish()
    }
  }

  /// A view that displays live transcription of the recording.
  ///
  /// - Parameter recording: The current recording state.
  @ViewBuilder
  private func liveTranscriptionView() -> some View {
    VStack(spacing: .grid(2)) {
      modelLoadingView(progress: store.liveTranscriptionState?.modelProgress ?? 0.0)
      transcribingView(recording: store.state, text: store.liveTranscriptionState?.currentText ?? "")

      Spacer()
    }
  }

  /// A view that displays the model loading progress.
  ///
  /// - Parameter progress: The current progress of the model loading.
  @ViewBuilder
  private func modelLoadingView(progress: Double) -> some View {
    LabeledContent {
      Text("\(Int(progress * 100)) %")
        .foregroundColor(.DS.Text.base)
        .textStyle(.body)
    } label: {
      HStack {
        Label("Model Loading", systemImage: "info.circle")
          .foregroundColor(.DS.Text.base)
          .textStyle(.body)

        Button(action: {
          store.send(.toggleModelLoadingInfo)
        }) {
          Image(systemName: "exclamationmark.circle.fill")
            .foregroundColor(.blue)
        }
        .popover(isPresented: $store.isModelLoadingInfoPresented) {
          Text("The model is currently loading. This process may take a few moments.")
            .padding()
        }
      }
    }
    .padding(.grid(4))
    .cardStyle()
    .fixedSize(horizontal: true, vertical: true)
  }

  /// A view that displays the transcribed text of the recording.
  ///
  /// - Parameters:
  ///   - recording: The current recording state.
  ///   - text: The transcribed text.
  @ViewBuilder
  private func transcribingView(recording: Recording.State, text: String) -> some View {
    ScrollView(showsIndicators: false) {
      Text(recording.recordingInfo.text)
        .textStyle(.body)
        .lineLimit(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .grid(2))
        .padding(.horizontal, .grid(4))

      Text(text)
        .multilineTextAlignment(.leading)
        .textStyle(.body)
        .opacity(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}