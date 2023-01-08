//
// Created by Igor Tarasenko on 08/01/2023.
//

import ComposableArchitecture
import SwiftUI

struct Settings: ReducerProtocol {
  struct State: Equatable {
    var modelSelector = ModelSelector.State()
  }

  enum Action: Equatable {
    case modelSelector(ModelSelector.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.modelSelector, action: /Action.modelSelector) {
      ModelSelector()
    }

    Reduce { state, action in
      .none
    }
  }
}

struct SettingsView: View {
  let store: StoreOf<Settings>
  @ObservedObject var viewStore: ViewStoreOf<Settings>

  init(store: StoreOf<Settings>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    Text("Settings feature")
    ModelSelectorView(store: store.scope(state: \.modelSelector, action: Settings.Action.modelSelector))
  }
}

struct Settings_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View {
      SettingsView(
        store: Store(
          initialState: Settings.State(),
          reducer: Settings()
        )
      )
    }
  }

  static var previews: some View {
    ContentView()
  }
}