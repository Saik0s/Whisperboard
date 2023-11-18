
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordScreen

struct RecordScreen: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var alert: AlertState<Action.Alert>?
    var micSelector = MicSelector.State()
    var recordingControls = RecordingControls.State()
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case micSelector(MicSelector.Action)
    case recordingControls(RecordingControls.Action)
    case alert(PresentationAction<Alert>)

    /// Delegate actions
    case newRecordingCreated(RecordingInfo)
    case goToNewRecordingTapped

    enum Alert: Equatable {}
  }

  @Dependency(\.storage) var storage: StorageClient
  @Dependency(\.settings) var settings: SettingsClient

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Scope(state: \.micSelector, action: /Action.micSelector) {
      MicSelector()
    }

    Scope(state: \.recordingControls, action: /Action.recordingControls) {
      RecordingControls()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case let .recordingControls(.recording(.delegate(.didFinish(.success(recording))))):
        let recordingInfo = RecordingInfo(
          fileName: recording.url.lastPathComponent,
          date: recording.date,
          duration: recording.duration
        )

        log.verbose("Adding recording info: \(recordingInfo)")
        do {
          try storage.addRecordingInfo(recordingInfo)
        } catch {
          state.alert = .error(error)
        }

        return .run { send in
          await send(.newRecordingCreated(recordingInfo))
          await send(.recordingControls(.binding(.set(\.$isGotToDetailsPopupPresented, true))))
        }

      case let .recordingControls(.recording(.delegate(.didFinish(.failure(error))))):
        state.alert = AlertState(
          title: TextState("Voice recording failed."),
          message: TextState(error.localizedDescription)
        )
        return .none

      case .recordingControls(.goToDetailsButtonTapped):
        return .run { send in
          await send(.goToNewRecordingTapped)
        }

      case .goToNewRecordingTapped:
        return .none

      case .recordingControls:
        return .none

      case .newRecordingCreated:
        return .none

      case .micSelector:
        return .none

      case .binding:
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
  }
}

// MARK: - RecordScreenView

struct RecordScreenView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordScreen>

  init(store: StoreOf<RecordScreen>) {
    self.store = store
  }

  var body: some View {
    WithViewStore(store, observe: { $0 }) { _ in
      VStack(spacing: 0) {
        MicSelectorView(store: store.scope(state: \.micSelector, action: { .micSelector($0) }))
        Spacer()
        RecordingControlsView(store: store.scope(state: \.recordingControls, action: { .recordingControls($0) }))
      }
      .padding(.top, .grid(4))
      .padding(.horizontal, .grid(4))
      .padding(.bottom, .grid(8))
      .ignoresSafeArea(edges: .bottom)
      .alert(
        store: store.scope(state: \.$alert, action: { .alert($0) })
      )
    }
    .enableInjection()
  }
}

#if DEBUG

  struct RecordScreenView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordScreenView(
          store: Store(
            initialState: RecordScreen.State(
              recordingControls: .init(recording: .init(date: Date(), url: URL(fileURLWithPath: "test")))
            ),
            reducer: { RecordScreen() }
          )
        )
      }
    }
  }
#endif
