import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordScreen

public struct RecordScreen: ReducerProtocol {
  public struct State: Equatable {
    @BindingState var alert: AlertState<Action>?
    var micSelector = MicSelector.State()
    var recordingControls = RecordingControls.State()
  }

  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case micSelector(MicSelector.Action)
    case recordingControls(RecordingControls.Action)

    // Delegate actions
    case newRecordingCreated(RecordingInfo)
  }

  public var body: some ReducerProtocol<State, Action> {
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
        return .task { .newRecordingCreated(recordingInfo) }

      case let .recordingControls(.recording(.delegate(.didFinish(.failure(error))))):
        state.alert = AlertState(
          title: TextState("Voice recording failed."),
          message: TextState(error.localizedDescription)
        )
        return .none

      case .recordingControls:
        return .none

      case .newRecordingCreated:
        return .none

      case .micSelector:
        return .none

      case .binding:
        return .none
      }
    }
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
    WithViewStore(store, observe: { $0 }) { _ in
      VStack(spacing: 0) {
        MicSelectorView(store: store.scope(state: \.micSelector, action: { .micSelector($0) }))
        Spacer()
        RecordingControlsView(store: store.scope(state: \.recordingControls, action: { .recordingControls($0) }))
      }
      .padding(.grid(4))
      .alert(store.scope(state: \.alert), dismiss: .binding(.set(\.$alert, nil)))
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
            initialState: RecordScreen.State(
              recordingControls: .init(recording: .init(date: Date(), url: URL(fileURLWithPath: "test")))
            ),
            reducer: RecordScreen()
          )
        )
      }
    }
  }
#endif
