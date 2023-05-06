import AppDevUtils
import ComposableArchitecture
import Inject
import Popovers
import RecognitionKit
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

    @BindingState var isParallelEnabled: Bool = false

    @BindingState var alert: AlertState<Action>?
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case modelSelector(ModelSelector.Action)
    case task
    case setLanguage(VoiceLanguage)
    case parallelSwitchTapped(Bool)
    case openGitHub
    case openPersonalWebsite
    case deleteStorageTapped
    case deleteDialogConfirmed
    case rateAppTapped
    case reportBugTapped
    case suggestFeatureTapped

    case showError(EquatableErrorWrapper)
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
        state.availableLanguages = transcriber.getAvailableLanguages().identifiedArray
        state.selectedLanguage = settingsClient.settings().voiceLanguage
        state.isParallelEnabled = settingsClient.settings().isParallelEnabled
        return .none

      case let .setLanguage(language):
        state.selectedLanguage = language
        return .run { _ in
          try await settingsClient.setValue(language, forKey: \.voiceLanguage)
        } catch: { error, send in
          await send(.showError(error.equatable))
        }

      case let .parallelSwitchTapped(switchState):
        state.isParallelEnabled = switchState
        return .run { [isParallelEnabled = state.isParallelEnabled] _ in
          try await settingsClient.setValue(isParallelEnabled, forKey: \.isParallelEnabled)
        } catch: { error, send in
          await send(.showError(error.equatable))
        }

      case .openGitHub:
        return .fireAndForget {
          await openURL(build.githubURL())
        }

      case .openPersonalWebsite:
        return .fireAndForget {
          await openURL(build.personalWebsiteURL())
        }

      case .deleteStorageTapped:
        createDeleteConfirmationDialog(state: &state)
        return .none

      case .deleteDialogConfirmed:
        return .run { send in
          try await diskSpace.deleteStorage()
          await send(.task)
        } catch: { error, send in
          await send(.showError(error.equatable))
        }

      case let .showError(error):
        state.alert = .error(error)
        return .none

      case .rateAppTapped:
        return .fireAndForget {
          await openURL(build.appStoreReviewURL())
        }

      case .reportBugTapped:
        return .fireAndForget {
          await openURL(build.bugReportURL())
        }

      case .suggestFeatureTapped:
        return .fireAndForget {
          await openURL(build.featureRequestURL())
        }
      }
    }
  }

  private func createDeleteConfirmationDialog(state: inout State) {
    state.alert = AlertState {
      TextState("Confirmation")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
      ButtonState(role: .destructive, action: .deleteDialogConfirmed) {
        TextState("Delete")
      }
    } message: {
      TextState("Are you sure you want to delete all recordings and all downloaded models?")
    }
  }
}

// MARK: - SettingsScreenView

struct SettingsScreenView: View {
  @ObserveInjection var inject

  let store: StoreOf<SettingsScreen>

  @ObservedObject var viewStore: ViewStoreOf<SettingsScreen>

  @State var debugPresent = false

  var modelSelectorStore: StoreOf<ModelSelector> {
    store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector)
  }

  init(store: StoreOf<SettingsScreen>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  var body: some View {
    SettingStack {
      SettingPage(title: "Settings", backgroundColor: .DS.Background.primary) {
        SettingGroup(header: "Transcription", backgroundColor: .DS.Background.secondary) {
          SettingPage(
            title: "Models",
            selectedChoice: viewStore.modelSelector.selectedModel.readableName,
            backgroundColor: .DS.Background.primary,
            previewConfiguration: .init(icon: .system(icon: "square.and.arrow.down", backgroundColor: .systemBlue))
          ) {
            SettingGroup(footer: .modelSelectorFooter) {}

            SettingGroup(header: "Whisper models", backgroundColor: .DS.Background.secondary) {
              SettingCustomView(id: "models") {
                ForEachStore(modelSelectorStore.scope(state: \.modelRows, action: ModelSelector.Action.modelRow)) { modelRowStore in
                  ModelRowView(store: modelRowStore)
                }
              }
            }
          }

          SettingPicker(
            icon: .system(icon: "globe", backgroundColor: .systemGreen.darken(by: 0.1)),
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

          #if DEBUG
            SettingToggle(title: "Parallel chunks transcription", isOn: viewStore.binding(
              get: \.isParallelEnabled,
              send: { .parallelSwitchTapped($0) }
            ))
          #endif
        }

        #if DEBUG
          SettingGroup(header: "Debug", backgroundColor: .DS.Background.secondary) {
            SettingButton(icon: .system(icon: "ladybug", backgroundColor: .systemRed.darken(by: 0.05)), title: "Show logs") {
              debugPresent = true
            }
            SettingCustomView {
              ZStack {}.popover(present: $debugPresent) {
                Text("Debug popup")
                  .padding()
                  .foregroundColor(.white)
                  .background(.blue)
                  .cornerRadius(16)
              }
            }
          }
        #endif

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

          SettingButton(icon: .system(icon: "trash", backgroundColor: .systemRed.darken(by: 0.1)), title: "Delete Storage", indicator: nil) {
            viewStore.send(.deleteStorageTapped)
          }
        }

        SettingGroup(backgroundColor: .DS.Background.secondary) {
          SettingButton(icon: .system(icon: "star.fill", backgroundColor: .systemYellow.darken(by: 0.05)), title: "Rate the App") {
            viewStore.send(.rateAppTapped)
          }

          SettingButton(icon: .system(icon: "exclamationmark.triangle", backgroundColor: .systemRed), title: "Report a Bug") {
            viewStore.send(.reportBugTapped)
          }

          SettingButton(icon: .system(icon: "sparkles", backgroundColor: .systemPurple.darken(by: 0.1)), title: "Suggest New Feature") {
            viewStore.send(.suggestFeatureTapped)
          }
        }

        SettingCustomView(id: "Footer", titleForSearch: "GitHub") {
          VStack(spacing: .grid(1)) {
            Text("v\(viewStore.appVersion)(\(viewStore.buildNumber))")
              .font(.DS.bodyM)
              .foregroundColor(.DS.Text.subdued)
            Text("Made with ♥ in Amsterdam")
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
    .alert(modelSelectorStore.scope(state: \.alert), dismiss: .binding(.set(\.$alert, nil)))
    .alert(store.scope(state: \.alert), dismiss: .binding(.set(\.$alert, nil)))
    .task { viewStore.send(.task) }
    .onAppear { viewStore.send(.modelSelector(.onAppear)) }
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

private extension String {
  static let modelSelectorFooter = """
  Whisper ASR, by OpenAI, is an advanced system that converts spoken words into written text. It's perfect for transcribing conversations or speeches.

  The model is a neural network that takes an audio file as input and outputs a sequence of characters.
  """
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
