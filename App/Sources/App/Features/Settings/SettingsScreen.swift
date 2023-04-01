import AppDevUtils
import ComposableArchitecture
import Inject
import Setting
import SwiftUI

// MARK: - SettingsScreen

struct SettingsScreen: ReducerProtocol {
  struct State: Equatable {
    var modelSelector = ModelSelector.State()

    var availableLanguages: IdentifiedArrayOf<VoiceLanguage> = []
    @BindingState var selectedLanguage: VoiceLanguage = .auto

    var alert: AlertState<Action>?
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case modelSelector(ModelSelector.Action)
    case task
    case fetchAvailableLanguages
    case setLanguage(VoiceLanguage)

    case showError(EquatableErrorWrapper)
    case dismissAlert
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient
  @Dependency(\.settings) var settingsClient: SettingsClient

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Scope(state: \.modelSelector, action: /Action.modelSelector) {
      ModelSelector()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .modelSelector:
        return .none

      case .task:
        return .send(.fetchAvailableLanguages)

      case .fetchAvailableLanguages:
        state.availableLanguages = transcriber.getAvailableLanguages().identifiedArray
        state.selectedLanguage = settingsClient.settings().voiceLanguage
        return .none

      case let .setLanguage(language):
        state.selectedLanguage = language
        return .run { _ in
          try await settingsClient.setValue(language, forKey: \.voiceLanguage)
        } catch: { error, send in
          await send(.showError(error.equatable))
        }

      case let .showError(error):
        state.alert = .init(
          title: TextState("Error"),
          message: TextState(String(describing: error)),
          dismissButton: .default(TextState("OK"), action: .send(Action.dismissAlert, animation: .default))
        )
        return .none

      case .dismissAlert:
        state.alert = nil
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
            SettingText(
              title: "Whisper is an automatic speech recognition (ASR) model developed by OpenAI. It uses deep learning techniques to transcribe spoken language into text. It is designed to be more accurate and efficient than traditional ASR models.\n\nThere are several different Whisper models available, each with different capabilities. The main difference between them is the size of the model, which affects the accuracy and efficiency of the transcription."
            )
            .font(.DS.footnote)
          }

          SettingPage(title: "Model picker") {
            SettingCustomView {
              ModelSelectorView(store: store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector))
            }
          }

          SettingPicker(
            title: "Language",
            choices: viewStore.availableLanguages.map(\.name.titleCased),
            selectedIndex: viewStore.binding(
              get: { $0.availableLanguages.firstIndex(of: $0.selectedLanguage) ?? 0 },
              send: { .setLanguage(viewStore.availableLanguages[$0]) }
            )
          )
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationBarTitle("Settings")
    .task { viewStore.send(.task) }
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
