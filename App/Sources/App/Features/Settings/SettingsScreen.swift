import AppDevUtils
import ComposableArchitecture
import Inject
import Setting
import SwiftUI

// MARK: - SettingsScreen

struct SettingsScreen: ReducerProtocol {
  struct State: Equatable {
    var modelSelector = ModelSelector.State()
    var availableLanguages: [String] = []
    @BindingState var selectedLanguageIndex: Int = 0
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case modelSelector(ModelSelector.Action)
    case task
    case fetchAvailableLanguages
    case setLanguage
  }

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Scope(state: \.modelSelector, action: /Action.modelSelector) {
      ModelSelector()
    }

    Reduce { state, action in
      switch action {
      case .task:
        return .none

      case .fetchAvailableLanguages:
        state.availableLanguages = transcriptionClient.getAvailableLanguages()
        return .none

      case .setLanguage:
        settingsClient.setLanguage(state.availableLanguages[state.selectedLanguageIndex])
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
    SettingStack {
      SettingPage(title: "Settings") {
        SettingGroup(header: "Transcription") {
          SettingCustomView {
            SettingText(title: "Whisper is an automatic speech recognition (ASR) model developed by OpenAI. It uses deep learning techniques to transcribe spoken language into text. It is designed to be more accurate and efficient than traditional ASR models.\n\nThere are several different Whisper models available, each with different capabilities. The main difference between them is the size of the model, which affects the accuracy and efficiency of the transcription.")
              .font(.DS.footnote)
          }
          SettingPage(title: "Model picker") {
            SettingCustomView {
              ModelSelectorView(store: store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector))
            }
          }
          SettingPicker(
           title: "Language",
            choices: viewStore.availableLanguages,
            selectedIndex: viewStore.binding(\.selectedLanguageIndex)
          )
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationBarTitle("Settings")
    .task {
      viewStore.send(.task)
      viewStore.send(.fetchAvailableLanguages)
    }
    .onChange(of: viewStore.selectedLanguageIndex) { _ in
      viewStore.send(.setLanguage)
    }
    .enableInjection()
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
