import AppDevUtils
import ComposableArchitecture
import Inject
import Setting
import SwiftUI

// MARK: - SettingsScreen

struct SettingsScreen: ReducerProtocol {
  struct State: Equatable {
    var modelSelector = ModelSelector.State()
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case modelSelector(ModelSelector.Action)
    case task
  }

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Scope(state: \.modelSelector, action: /Action.modelSelector) {
      ModelSelector()
    }

    Reduce { _, action in
      switch action {
      case .task:
        return .none

      default:
        return .none
      }
    }
  }
}

// MARK: - SettingsScreenView

struct SettingsScreenView: View {
  @ObserveInjection var inject

  let store: StoreOf<SettingsScreen>
  @ObservedObject var viewStore: ViewStoreOf<SettingsScreen>

  init(store: StoreOf<SettingsScreen>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    // TODO: Rewrite model selector to use SettingStack
    SettingStack {
      SettingPage(title: "Settings") {
        SettingCustomView {
          ModelSelectorView(store: store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector))
            .frame(minHeight: UIScreen.main.bounds.height)
            .frame(maxHeight: .infinity)
            .fixedSize(horizontal: false, vertical: true)
        }
        //   SettingGroup(header: "Transcription") {
        //     SettingPage(title: "Model picker") {
        //       SettingCustomView {
        //         ModelSelectorView(store: store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector))
        //       }
        //     }
        //   }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationBarTitle("Settings")
    .task { viewStore.send(.task) }
    .enableInjection()

    // NavigationView {
    //   List {
    //     Section(header: Text("Transcription")) {
    //       NavigationLink(destination: ModelSelectorView(store: store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector))) {
    //         HStack(spacing: .grid(4)) {
    //           Text("🤖")
    //           Text("Transcription Model")
    //         }
    //       }
    //     }
    //     .listRowBackground(Color.DS.Background.secondary)
    //   }
    //   .screenRadialBackground()
    // }
    // .scrollContentBackground(.hidden)
    // .navigationBarTitle("Settings")
    // .task { viewStore.send(.task) }
    // .enableInjection()
  }
}

// MARK: - SettingsScreen_Previews

struct SettingsScreen_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View {
      SettingsScreenView(
        store: Store(
          initialState: SettingsScreen.State(),
          reducer: SettingsScreen()
        )
      )
    }
  }

  static var previews: some View {
    ContentView()
  }
}
