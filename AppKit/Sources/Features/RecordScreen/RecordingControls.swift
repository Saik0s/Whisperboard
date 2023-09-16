
import ComposableArchitecture
import DSWaveformImage
import DSWaveformImageViews
import Foundation
import Inject
import Popovers
import SwiftUI

// MARK: - RecordingControls

struct RecordingControls: ReducerProtocol {
  struct State: Equatable {
    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }

    @BindingState var alert: AlertState<Action>?
    @BindingState var isGotToDetailsPopupPresented: Bool = false

    var recording: Recording.State?

    var audioRecorderPermission = RecorderPermission.undetermined

    init(recording: Recording.State? = nil) {
      self.recording = recording
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case recordPermissionResponse(Bool)
    case openSettingsButtonTapped
    case recordButtonTapped
    case recording(Recording.Action)
    case goToDetailsButtonTapped
  }

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.date) var date
  @Dependency(\.storage) var storage
  @Dependency(\.continuousClock) var clock

  var body: some ReducerProtocolOf<Self> {
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
          state.recording = createNewRecording()
          return .run { send in
            await send(.recording(.task))
          }
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
          state.recording = createNewRecording()
          return .run { send in
            await send(.recording(.task))
          }
        } else {
          state.alert = micPermissionAlert
          return .none
        }

      case .openSettingsButtonTapped:
        return .run { _ in
          await openSettings()
        }

      case .binding(.set(\.$isGotToDetailsPopupPresented, true)):
        return .run { send in
          try await clock.sleep(for: .seconds(5))
          await send(.binding(.set(\.$isGotToDetailsPopupPresented, false)))
        }

      case .goToDetailsButtonTapped:
        state.isGotToDetailsPopupPresented = false
        return .none

      case .binding:
        return .none
      }
    }
    .ifLet(\.recording, action: /Action.recording) { Recording() }
  }

  private func createNewRecording() -> Recording.State {
    Recording.State(
      date: date.now,
      url: storage.createNewWhisperURL()
    )
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

  let store: StoreOf<RecordingControls>

  @ObservedObject var viewStore: ViewStoreOf<RecordingControls>

  var currentTime: String {
    (viewStore.recording?.duration).flatMap {
      dateComponentsFormatter.string(from: $0)
    } ?? ""
  }

  init(store: StoreOf<RecordingControls>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  var body: some View {
    VStack(spacing: .grid(3)) {
      WaveformLiveCanvas(samples: viewStore.recording?.samples ?? [], configuration: Waveform.Configuration(
        backgroundColor: .clear,
        style: .striped(.init(color: UIColor(Color.DS.Text.base), width: 2, spacing: 4, lineCap: .round)),
        dampening: .init(percentage: 0.125, sides: .both),
        position: .middle,
        scale: DSScreen.scale,
        verticalScalingFactor: 0.95,
        shouldAntialias: true
      ))
      .frame(maxWidth: .infinity)

      Text(currentTime)
        .font(.DS.titleL)
        .monospaced()
        .foregroundColor(.DS.Text.accent)

      HStack(spacing: .grid(8)) {
        if viewStore.recording?.mode == .paused {
          Button { viewStore.send(.recording(.deleteButtonTapped), animation: .default) }
            label: {
              Image(systemName: "multiply")
                .font(.DS.titleL)
                .frame(width: 50, height: 50)
                .containerShape(Rectangle())
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }

        ZStack {
          if viewStore.recording?.mode == .recording {
            Button { viewStore.send(.recording(.pauseButtonTapped), animation: .default) } label: {
              Circle()
                .fill(RadialGradient.accent)
                .shadow(color: .DS.Background.accent.opacity(0.5), radius: 20)
                .overlay(Image(systemName: "pause.fill")
                  .font(.DS.titleL)
                  .foregroundColor(.DS.Text.base))
            }
            .recordButtonStyle()
          } else if viewStore.recording?.mode == .paused {
            Button { viewStore.send(.recording(.continueButtonTapped), animation: .default) } label: {
              Circle()
                .fill(RadialGradient.accent)
                .overlay(Image(systemName: "mic")
                  .font(.DS.titleL)
                  .foregroundColor(.DS.Text.base))
            }
            .recordButtonStyle()
          } else {
            RecordButton(permission: viewStore.audioRecorderPermission) {
              viewStore.send(.recordButtonTapped, animation: .default)
            } settingsAction: {
              viewStore.send(.openSettingsButtonTapped)
            }
          }
        }
        .frame(width: 70, height: 70)

        if viewStore.recording?.mode == .paused {
          Button { viewStore.send(.recording(.saveButtonTapped), animation: .default) }
            label: {
              Image(systemName: "checkmark")
                .font(.DS.titleL)
                .frame(width: 50, height: 50)
                .containerShape(Rectangle())
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
      }
      .padding(.horizontal, .grid(3))
      .popover(
        present: viewStore.$isGotToDetailsPopupPresented,
        attributes: {
          $0.position = .absolute(
            originAnchor: .top,
            popoverAnchor: .bottom
          )
          $0.presentation = .init(animation: .gentleBounce(), transition: .move(edge: .bottom))
          $0.dismissal = .init(
            animation: .gentleBounce(),
            transition: .move(edge: .bottom),
            mode: .dragDown
          )
        }
      ) {
        VStack {
          Text("Go to new recording?")
            .font(.DS.headlineM)
            .foregroundColor(.DS.Text.base)

          Button("Open Recording") {
            viewStore.send(.goToDetailsButtonTapped)
          }.secondaryButtonStyle()
        }
        .padding(.grid(2))
        .cardStyle()
        .padding(.grid(2))
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
