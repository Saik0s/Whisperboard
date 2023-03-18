import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordScreen

public struct RecordScreen: ReducerProtocol {
  public struct State: Equatable {
    var alert: AlertState<Action>?
    var audioRecorderPermission = RecorderPermission.undetermined
    var recording: Recording.State?
    var micSelector = MicSelector.State()

    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }
  }

  public enum Action: Equatable {
    case recordButtonTapped
    case recordPermissionResponse(Bool)
    case recording(Recording.Action)
    case openSettingsButtonTapped
    case alertDismissed
    case newRecordingCreated(RecordingInfo)
    case micSelector(MicSelector.Action)
  }

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.date) var date
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.storage) var storage

  public var body: some ReducerProtocol<State, Action> {
    Scope(state: \.micSelector, action: /Action.micSelector) { MicSelector() }

    Reduce<State, Action> { state, action in
      switch action {
      case .recordButtonTapped:
        switch state.audioRecorderPermission {
        case .undetermined:
          return .task {
            await .recordPermissionResponse(self.requestRecordPermission())
          }

        case .denied:
          state.alert = AlertState(
            title: TextState("Permission is required to record voice.")
          )
          return .none

        case .allowed:
          state.recording = newRecording
          return .none
        }

      case let .recording(.delegate(.didFinish(.success(recording)))):
        state.recording = nil
        let recordingInfo = RecordingInfo(
          fileName: recording.url.lastPathComponent,
          date: recording.date,
          duration: recording.duration
        )
        return .task { .newRecordingCreated(recordingInfo) }

      case let .recording(.delegate(.didFinish(.failure(error)))):
        state.recording = nil
        state.alert = AlertState(
          title: TextState("Voice recording failed."),
          message: TextState(error.localizedDescription)
        )
        return .none

      case let .recording(.delegate(.didCancel)):
        state.recording = nil
        return .none

      case .recording:
        return .none

      case let .recordPermissionResponse(permission):
        state.audioRecorderPermission = permission ? .allowed : .denied
        if permission {
          state.recording = newRecording
        } else {
          state.alert = AlertState(
            title: TextState("Permission is required to record voice.")
          )
        }
        return .none

      case .openSettingsButtonTapped:
        return .fireAndForget {
          await self.openSettings()
        }

      case .alertDismissed:
        state.alert = nil
        return .none

      case .newRecordingCreated:
        return .none

      case .micSelector:
        return .none
      }
    }
    .ifLet(\.recording, action: /Action.recording) { Recording() }
  }

  private var newRecording: Recording.State {
    Recording.State(
      date: date.now,
      url: storage.createNewWhisperURL()
    )
  }
}

// MARK: - RecordScreenView

public struct RecordScreenView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordScreen>

  public init(store: StoreOf<RecordScreen>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      VStack(spacing: 0) {
        MicSelectorView(store: store.scope(state: \.micSelector, action: { .micSelector($0) }))
        Spacer()
        IfLetStore(
          store.scope(state: \.recording, action: { .recording($0) })
        ) { store in
          RecordingView(store: store)
        } else: {
          RecordButton(permission: viewStore.audioRecorderPermission) {
            viewStore.send(.recordButtonTapped, animation: .default)
          } settingsAction: {
            viewStore.send(.openSettingsButtonTapped)
          }
        }
      }
      .padding(.grid(4))
      .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
    }
    .screenRadialBackground()
    .enableInjection()
  }
}

#if DEBUG
  struct RecordScreenView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordScreenView(
          store: Store(
            initialState: RecordScreen.State(recording: .init(date: Date(), url: URL(fileURLWithPath: "test"))),
            reducer: RecordScreen()
          )
        )
      }
    }
  }
#endif
