import AudioProcessing
import Common
import ComposableArchitecture
import DSWaveformImage
import DSWaveformImageViews
import Foundation
import Inject
import Popovers
import SwiftUI

// MARK: - RecordingControls

/// A reducer that manages the state and actions related to recording controls.
@Reducer
struct RecordingControls {
  /// The state of the recording controls.
  @ObservableState
  struct State: Equatable {
    /// Permissions for the recorder.
    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }

    var alert: AlertState<Action>?
    var recording: Recording.State?
    var audioRecorderPermission = RecorderPermission.undetermined
    var isModelLoadingInfoPresented = false
  }

  /// Actions that can be performed on the recording controls.
  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case recording(Recording.Action)
    case recordButtonTapped
    case openSettingsButtonTapped
    case toggleModelLoadingInfo
  }

  @Dependency(\.audioSession.requestRecordPermission) var requestRecordPermission
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.date) var date
  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid

  /// Identifiers for cancellable effects.
  enum CancelID: Hashable { case recording }

  /// The body of the reducer, defining how state changes in response to actions.
  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce<State, Action> { state, action in
      switch action {
      case .recordButtonTapped where state.audioRecorderPermission == .undetermined:
        return .run { send in
          let permission = await requestRecordPermission()
          await send(.set(\.audioRecorderPermission, permission ? .allowed : .denied))
          if permission {
            await send(.set(\.recording, createNewRecording()))
          }
        }

      case .recordButtonTapped where state.audioRecorderPermission == .allowed:
        state.recording = createNewRecording()
        return .none

      case .recordButtonTapped:
        assertionFailure("Can't press record button when permission is denied")
        return .none

      case .recording(.delegate(.didCancel)):
        state.recording = nil
        return .cancel(id: CancelID.recording)

      case .recording(.delegate(.didFinish(.success))):
        state.recording = nil
        return .cancel(id: CancelID.recording)

      case .recording(.delegate(.didFinish(.failure))):
        state.recording = nil
        return .cancel(id: CancelID.recording)

      case .recording:
        return .none

      case .openSettingsButtonTapped:
        return .run { _ in
          await openSettings()
        }

      case .binding:
        return .none

      case .toggleModelLoadingInfo:
        state.isModelLoadingInfoPresented.toggle()
        return .none
      }
    }
    .ifLet(\.recording, action: \.recording) { Recording() }
  }

  private func createNewRecording() -> Recording.State {
    let newInfo = RecordingInfo(id: uuid().uuidString, date: date.now)
    return Recording.State(recordingInfo: newInfo)
  }

  /// An alert state for microphone permission denial.
  private var micPermissionAlert: AlertState<Action> {
    AlertState(
      title: TextState("Permission is required to record voice."),
      message: TextState("Please enable microphone access in Settings."),
      primaryButton: .default(TextState("Open Settings"), action: .send(.openSettingsButtonTapped)),
      secondaryButton: .cancel(TextState("Cancel"))
    )
  }
}

// MARK: - RecordingControlsView

/// A view that provides controls for recording audio.
struct RecordingControlsView: View {
  @Perception.Bindable var store: StoreOf<RecordingControls>
  @Environment(NamespaceContainer.self) var namespace

  /// The current time of the recording formatted as a string.
  var currentTime: String {
    (store.recording?.recordingInfo.duration).flatMap {
      dateComponentsFormatter.string(from: $0)
    } ?? ""
  }

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(3)) {
        if let recording = store.recording {
          liveTranscriptionView(recording)
        }

        WaveformLiveCanvas(samples: store.recording?.samples ?? [], configuration: Waveform.Configuration(
          backgroundColor: .clear,
          style: .striped(.init(color: UIColor(Color.DS.Text.base), width: 2, spacing: 4, lineCap: .round)),
          damping: .init(percentage: 0.125, sides: .both),
          scale: DSScreen.scale,
          verticalScalingFactor: 0.95,
          shouldAntialias: true
        ))
        .frame(maxWidth: .infinity)
      }

      Text(currentTime)
        .foregroundColor(.DS.Text.accent)
        .textStyle(.navigationTitle)
        .monospaced()

      HStack(spacing: .grid(8)) {
        if store.recording?.mode == .paused {
          Button { store.send(.recording(.deleteButtonTapped), animation: .showHide()) }
            label: {
              Image(systemName: "multiply")
                .textStyle(.navigationTitle)
                .frame(width: 50, height: 50)
                .containerShape(Rectangle())
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }

        ZStack {
          if store.recording?.mode == .recording {
            Button { store.send(.recording(.pauseButtonTapped), animation: .showHide()) } label: {
              Circle()
                .fill(RadialGradient.accent)
                .shadow(color: .DS.Background.accent.opacity(0.5), radius: 20)
                .overlay(Image(systemName: "pause.fill").textStyle(.headline))
            }
            .recordButtonStyle()
            .matchedGeometryEffect(id: "mic", in: namespace.namespace)
          } else if store.recording?.mode == .paused {
            Button { store.send(.recording(.continueButtonTapped), animation: .showHide()) } label: {
              Circle()
                .fill(RadialGradient.accent)
                .overlay(Image(systemName: "mic").textStyle(.headline))
            }
            .recordButtonStyle()
            .matchedGeometryEffect(id: "mic", in: namespace.namespace)
          } else {
            RecordButton(permission: store.audioRecorderPermission) {
              store.send(.recordButtonTapped, animation: .showHide())
            } settingsAction: {
              store.send(.openSettingsButtonTapped)
            }
          }
        }
        .frame(width: 70, height: 70)

        if store.recording?.mode == .paused {
          Button { store.send(.recording(.saveButtonTapped), animation: .showHide()) }
            label: {
              Image(systemName: "checkmark")
                .textStyle(.navigationTitle)
                .frame(width: 50, height: 50)
                .containerShape(Rectangle())
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
      }
      .padding(.horizontal, .grid(3))
    }
  }

  /// A view that displays live transcription of the recording.
  ///
  /// - Parameter recording: The current recording state.
  @ViewBuilder
  private func liveTranscriptionView(_ recording: Recording.State) -> some View {
    VStack(spacing: .grid(2)) {
      modelLoadingView(progress: recording.liveTranscriptionState?.modelProgress ?? 0.0)
      transcribingView(recording: recording, text: recording.liveTranscriptionState?.currentText ?? "")

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
        .foregroundColor(.DS.Text.base)
        .textStyle(.body)
        .lineLimit(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .grid(2))
        .padding(.horizontal, .grid(4))

      #if DEBUG
        Text(text)
          .multilineTextAlignment(.leading)
          .textStyle(.body)
          .frame(maxWidth: .infinity, alignment: .leading)
      #endif
    }
  }
}
