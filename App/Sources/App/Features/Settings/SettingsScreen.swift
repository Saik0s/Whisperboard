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
    var appVersion: String = ""
    var buildNumber: String = ""
    var freeSpace: String = ""
    var takenSpace: String = ""
    var takenSpacePercentage: Double = 0

    var alert: AlertState<Action>?
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case modelSelector(ModelSelector.Action)
    case task
    case fetchAvailableLanguages
    case setLanguage(VoiceLanguage)
    case openGitHub
    case openPersonalWebsite
    case deleteStorageTapped

    case showError(EquatableErrorWrapper)
    case dismissAlert
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient
  @Dependency(\.settings) var settingsClient: SettingsClient
  @Dependency(\.openURL) var openURL: OpenURLEffect
  @Dependency(\.build) var build: BuildClient
  @Dependency(\.diskSpace) var diskSpace: DiskSpaceClient

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
        state.appVersion = build.version()
        state.buildNumber = build.buildNumber()
        state.freeSpace = diskSpace.freeSpace().readableString
        state.takenSpace = diskSpace.takenSpace().readableString
        state.takenSpacePercentage = 1 - Double(diskSpace.freeSpace()) / Double(diskSpace.freeSpace() + diskSpace.takenSpace())
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
          await openURL(build.githubURL())
        }

      case .openPersonalWebsite:
        return .fireAndForget {
          await openURL(URL(staticString: "https://igortarasenko.me"))
        }

      case .deleteStorageTapped:
        return .run { send in
          try await diskSpace.deleteStorage()
          await send(.task)
        } catch: { error, send in
          await send(.showError(error.equatable))
        }

      case let .showError(error):
        state.alert = .error(error)
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
                Text("Taken: \(viewStore.takenSpace)")
                  .font(.DS.bodyM)
                  .foregroundColor(.DS.Text.base)
                Spacer()
                Text("Available: \(viewStore.freeSpace)")
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
                  .frame(width: geometry.size.width * viewStore.takenSpacePercentage)
                  Color.DS.Background.tertiary
                }
              }
              .frame(height: .grid(4))
              .continuousCornerRadius(.grid(1))
            }
            .padding(.horizontal, .grid(4))
            .padding(.vertical, .grid(2))
          }

          SettingButton(title: "Delete Storage", indicator: "trash") {
            viewStore.send(.deleteStorageTapped)
          }
        }

        SettingCustomView(id: "Footer", titleForSearch: "GitHub") {
          VStack(spacing: .grid(1)) {
            Text("v\(viewStore.appVersion)(\(viewStore.buildNumber))")
              .font(.DS.bodyM)
              .foregroundColor(.DS.Text.subdued)
            Text("Made with ❤ in Amsterdam")
              .font(.DS.bodyM)
              .mask {
                LinearGradient.easedGradient(
                  colors: [
                    .systemPurple,
                    .systemRed,
                  ],
                  startPoint: .bottomLeading,
                  endPoint: .topTrailing
                )
              }
            Button { viewStore.send(.openPersonalWebsite) } label: {
              Text("by Igor Tarasenko")
                .font(.DS.bodyM)
                .foregroundColor(.DS.Text.accentAlt)
            }
          }
          .frame(maxWidth: .infinity)

          HStack(spacing: .grid(1)) {
            Button("Saik0s/Whisperboard") {
              viewStore.send(.openGitHub)
            }
          }
          .buttonStyle(SmallButtonStyle())
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

// MARK: - SmallButtonStyle

struct SmallButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.DS.bodyM)
      .foregroundColor(.DS.Text.accentAlt)
      .padding(.horizontal, .grid(2))
      .padding(.vertical, .grid(1))
      .background(
        RoundedRectangle(cornerRadius: .grid(1))
          .fill(Color.DS.Background.accentAlt.opacity(0.2))
      )
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
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
