//
// Settings.swift
//

import ComposableArchitecture
import SwiftUI

// MARK: - Settings

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

    Reduce { _, _ in
      .none
    }
  }
}

// MARK: - SettingsView

struct SettingsView: View {
  let store: StoreOf<Settings>
  @ObservedObject var viewStore: ViewStoreOf<Settings>

  init(store: StoreOf<Settings>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    ModelSelectorView(store: store.scope(state: \.modelSelector, action: Settings.Action.modelSelector))
  }
}

// MARK: - Settings_Previews

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
