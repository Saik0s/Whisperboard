import Foundation

import AppDevUtils
import Inject
import SwiftUI
import ComposableArchitecture

public struct RecordScreen: ReducerProtocol {
  public struct State: Equatable {
  }

  public enum Action: Equatable {
    case placeholder
  }

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .placeholder:
        return .none
      }
    }
  }
}

public struct RecordScreenView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordScreen>

  public init(store: StoreOf<RecordScreen>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Text("RecordScreen Feature")
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
