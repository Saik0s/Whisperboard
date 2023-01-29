import ComposableArchitecture
import SwiftUI
import AppDevUtils

extension UserDefaults {
  var openAIAPIKey: String? {
    get { string(forKey: #function) }
    set { set(newValue, forKey: #function) }
  }
}

// MARK: - Settings

struct Settings: ReducerProtocol {
  struct State: Equatable {
    var modelSelector = ModelSelector.State()
    @BindingState var openAIAPIKey: String = ""
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

    Reduce { state, action in
      switch action {
      case .task:
        state.openAIAPIKey = UserDefaults.standard.openAIAPIKey ?? ""
        return .none

      case .binding(\.$openAIAPIKey):
        UserDefaults.standard.openAIAPIKey = state.openAIAPIKey
        return .none

      default:
        return .none
      }
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
    ScrollView {
      VStack(spacing: .grid(4)) {
        ModelSelectorView(store: store.scope(state: \.modelSelector, action: Settings.Action.modelSelector))

        VStack(alignment: .leading, spacing: .grid(1)) {
          Text("OpenAI API Key for experimental transcription improvement:")
            .font(.DS.bodyS)
            .foregroundColor(.DS.Text.base)
          TextField("OpenAI API Key", text: viewStore.binding(\.$openAIAPIKey))
            .textFieldStyle(RoundedBorderTextFieldStyle())
          Text("Go to OpenAI website to create your API key https://beta.openai.com/account/api-keys")
            .font(.DS.footnote)
            .foregroundColor(.DS.Text.subdued)
        }
        .multilineTextAlignment(.leading)
        .padding(.grid(2))
        .background {
          RoundedRectangle(cornerRadius: .grid(4))
            .fill(Color.DS.Background.secondary)
        }
      }
    }
    .padding(.grid(2))
    .background(LinearGradient.screenBackground)
    .navigationBarTitle("Settings")
    .task { viewStore.send(.task) }
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
