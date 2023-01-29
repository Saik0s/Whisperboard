import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingListScreen

public struct RecordingListScreen: ReducerProtocol {
  public struct State: Equatable {}

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
  }

  public var body: some ReducerProtocol<State, Action> {
    CombineReducers {
      BindingReducer()

      Reduce<State, Action> { _, action in
        switch action {
        case .binding:
          return .none
        }
      }
    }
  }
}

// MARK: - RecordingListScreenView

public struct RecordingListScreenView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordingListScreen>

  public init(store: StoreOf<RecordingListScreen>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { _ in
      Text("RecordingListScreen Feature")
    }
    .enableInjection()
  }
}

#if DEBUG
  struct RecordingListScreenView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordingListScreenView(
          store: Store(
            initialState: RecordingListScreen.State(),
            reducer: RecordingListScreen()
          )
        )
      }
    }
  }
#endif
