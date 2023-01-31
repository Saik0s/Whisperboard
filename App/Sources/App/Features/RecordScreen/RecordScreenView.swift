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
  }

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.date) var date
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.storage) var storage

  public var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .recordButtonTapped:
        switch state.audioRecorderPermission {
        case .undetermined:
          UIImpactFeedbackGenerator(style: .light).impactOccurred()

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
          .merge(with: .cancel(id: Recording.CancelID()))

      case .recording(.delegate(.didFinish(.failure))):
        state.alert = AlertState(title: TextState("Voice recording failed."))
        state.recording = nil
        return .cancel(id: Recording.CancelID())

      case .recording:
        return .none

      case let .recordPermissionResponse(permission):
        state.audioRecorderPermission = permission ? .allowed : .denied
        if permission {
          state.recording = newRecording
          return .none
        } else {
          state.alert = AlertState(
            title: TextState("Permission is required to record voice.")
          )
          return .none
        }

      case .openSettingsButtonTapped:
        return .fireAndForget {
          await self.openSettings()
        }

      case .alertDismissed:
        state.alert = nil
        return .none

      case .newRecordingCreated:
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
      IfLetStore(
        store.scope(state: \.recording, action: { .recording($0) })
      ) { store in
        RecordingView(store: store)
      } else: {
        RecordButton(permission: viewStore.audioRecorderPermission) {
          viewStore.send(.recordButtonTapped, animation: .spring())
        } settingsAction: {
          viewStore.send(.openSettingsButtonTapped)
        }
        .shadow(color: .DS.Shadow.primary, radius: 20)
      }
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
    }
    .navigationTitle("RecordScreen")
    .enableInjection()
  }
}

#if DEBUG
  struct RecordScreenView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordScreenView(
          store: Store(
            initialState: RecordScreen.State(),
            reducer: RecordScreen()
          )
        )
      }
    }
  }
#endif
