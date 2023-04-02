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
    case openGitHub

    case showError(EquatableErrorWrapper)
    case dismissAlert
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient
  @Dependency(\.settings) var settingsClient: SettingsClient
  @Dependency(\.openURL) var openURL: OpenURLEffect

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

      case .openGitHub:
        return .fireAndForget {
          await openURL(URL(staticString: "https://github.com/Saik0s/Whisperboard"))
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
      SettingPage(title: "Settings", backgroundColor: .DS.Background.primary) {
        SettingGroup(header: "Transcription", backgroundColor: .DS.Background.secondary) {
          ModelSelectorSettingPage(store: store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector))

          SettingPicker(
            title: "Language",
            choices: viewStore.availableLanguages.map(\.name.titleCased),
            selectedIndex: viewStore.binding(
              get: { $0.availableLanguages.firstIndex(of: $0.selectedLanguage) ?? 0 },
              send: { .setLanguage(viewStore.availableLanguages[$0]) }
            ),
            choicesConfiguration: .init(
              groupBackgroundColor: .DS.Background.secondary
            )
          )
        }
        SettingGroup(header: "Storage", backgroundColor: .DS.Background.secondary) {
          SettingCustomView {
            VStack(alignment: .leading, spacing: .grid(1)) {
              HStack(spacing: 0) {
                Text("Taken: 2.5 GB")
                  .font(.DS.bodyM)
                  .foregroundColor(.DS.Text.base)
                Spacer()
                Text("Available: 7.5 GB")
                  .font(.DS.bodyM)
                  .foregroundColor(.DS.Text.base)
              }

              GeometryReader { geometry in
                HStack(spacing: 0) {
                  LinearGradient.easedGradient(
                    colors: [
                      .systemPurple,
                      .systemOrange,
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                  )
                  .frame(width: geometry.size.width * 0.25)
                  Color.DS.Background.tertiary
                }
              }
              .frame(height: .grid(4))
              .continuousCornerRadius(.grid(1))
            }
            .padding(.horizontal, .grid(4))
            .padding(.vertical, .grid(2))
          }

          SettingButton(title: "Delete Storage", indicator: "trash") {}
        }

        SettingCustomView(id: "Custom Footer", titleForSearch: "Welcome to Setting!") {
          Button { viewStore.send(.openGitHub) } label: {
            Text("Saik0s/Whisperboard")
              .foregroundColor(.white)
              .font(.DS.headlineL)
              .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
              .frame(maxWidth: .infinity)
              .padding(.grid(5))
              .background {
                LinearGradient.easedGradient(
                  colors: [
                    .systemPurple,
                    .systemRed,
                  ],
                  startPoint: .bottomLeading,
                  endPoint: .topTrailing
                )
              }
              .cornerRadius(.grid(3))
              .padding(.horizontal, .grid(4))
          }
          .padding(.top, .grid(4))
          .frame(maxHeight: .infinity, alignment: .bottom)

          VStack(spacing: .grid(1)) {
            Text("Version: 1.0.0")
              .font(.DS.bodyM)
              .foregroundColor(.DS.Text.subdued)
            Text("Build: 123")
              .font(.DS.bodyM)
              .foregroundColor(.DS.Text.subdued)
            Image(systemName: "mic.fill")
              .font(.DS.headlineL)
              .foregroundColor(.DS.Text.subdued)
              .opacity(0.5)
          }
          .frame(maxWidth: .infinity)
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
