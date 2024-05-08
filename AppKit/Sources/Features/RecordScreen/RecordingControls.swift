import ComposableArchitecture
import DSWaveformImage
import DSWaveformImageViews
import Foundation
import Inject
import Popovers
import SwiftUI

// MARK: - RecordingControls

@Reducer
struct RecordingControls {
  @ObservableState
  struct State: Equatable {
    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }

    var alert: AlertState<Action>?
    var recording: Recording.State?
    var audioRecorderPermission = RecorderPermission.undetermined
    var isGoToNewRecordingPopupPresented = false
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case recording(Recording.Action)
    case recordPermissionResponse(Bool)
    case recordButtonTapped
    case openSettingsButtonTapped
    case goToNewRecordingButtonTapped
  }

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.date) var date
  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce<State, Action> { state, action in
      switch action {
      case .recordButtonTapped:
        switch state.audioRecorderPermission {
        case .undetermined:
          return .run { send in
            await send(.recordPermissionResponse(requestRecordPermission()))
          }

        case .denied:
          state.alert = micPermissionAlert
          return .none

        case .allowed:
          return startRecording(&state)
        }

      case .recording(.delegate(.didCancel)):
        state.recording = nil
        return .none

      case .recording(.delegate(.didFinish(.success))):
        state.recording = nil
        return .none

      case .recording(.delegate(.didFinish(.failure))):
        state.recording = nil
        return .none

      case .recording:
        return .none

      case let .recordPermissionResponse(permission):
        state.audioRecorderPermission = permission ? .allowed : .denied
        if permission {
          return startRecording(&state)
        } else {
          state.alert = micPermissionAlert
          return .none
        }

      case .openSettingsButtonTapped:
        return .run { _ in
          await openSettings()
        }

      case .binding(.set(\.isGoToNewRecordingPopupPresented, true)):
        return .run { send in
          try await clock.sleep(for: .seconds(5))
          await send(.binding(.set(\.isGoToNewRecordingPopupPresented, false)))
        }

      case .goToNewRecordingButtonTapped:
        state.isGoToNewRecordingPopupPresented = false
        return .none

      case .binding:
        return .none
      }
    }
    .ifLet(\.recording, action: \.recording) { Recording() }
  }

  private func startRecording(_ state: inout State) -> Effect<Action> {
    state.recording = Recording.State(recordingInfo: RecordingInfo(id: uuid().uuidString, title: "New Recording", date: date.now, duration: 0))
    return .run { send in
      await send(.recording(.task))
    }
  }

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

struct RecordingControlsView: View {
  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<RecordingControls>
  @Environment(NamespaceContainer.self) var namespace

  var currentTime: String {
    (store.recording?.duration).flatMap {
      dateComponentsFormatter.string(from: $0)
    } ?? ""
  }

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(3)) {
        WaveformLiveCanvas(samples: store.recording?.samples ?? [], configuration: Waveform.Configuration(
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
        .animation(.easeIn(duration: 0.1), value: store.recording)
        .popover(
          present: $store.isGoToNewRecordingPopupPresented,
          attributes: {
            $0.position = .absolute(originAnchor: .top, popoverAnchor: .bottom)
            $0.presentation = .init(animation: .hardShowHide(), transition: .move(edge: .bottom).combined(with: .opacity))
            $0.dismissal = .init(
              animation: .hardShowHide(),
              transition: .move(edge: .bottom).combined(with: .opacity),
              mode: [.dragDown, .tapOutside]
            )
          }
        ) {
          VStack(spacing: .grid(4)) {
            Text("View the new recording?")
              .textStyle(.label)
              .foregroundColor(.DS.Text.base)

            Button("View Recording") {
              store.send(.goToNewRecordingButtonTapped)
            }.secondaryButtonStyle()
          }
          .padding(.grid(3))
          .cardStyle()
          .enableInjection()
        }
      }
    }
    .enableInjection()
  }
}

#if DEBUG

  struct RecordingControlsView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordingControlsView(
          store: Store(initialState: RecordingControls.State()) {
            RecordingControls()
          }
        )
      }
    }
  }
#endif
