import AudioProcessing
import Common
import ComposableArchitecture
import Inject
import Popovers
import SwiftUI
import SwiftUIIntrospect
import WhisperKit

// MARK: - SettingsScreen

@Reducer
struct SettingsScreen {
  @ObservableState
  struct State: Equatable {
    @Shared(.settings) var settings: Settings
    var modelSelector: ModelSelector.State = .init()
    var subscriptionSection: SubscriptionSection.State = .init()

    let availableLanguages: [String] = Constants.languages.keys.sorted()
    var appVersion: String = ""
    var buildNumber: String = ""
    var freeSpace: String = ""
    var takenSpace: String = ""
    var takenSpacePercentage: Double = 0
    var isSubscribed = false

    var isICloudSyncInProgress = false
    var isDebugLogPresented = false
    var isModelSelectorPresented = false

    @Presents var alert: AlertState<Action.Alert>?

    var selectedLanguageIndex: Int {
      get { settings.voiceLanguage.flatMap { availableLanguages.firstIndex(of: $0) } ?? 0 }
      set { settings.voiceLanguage = availableLanguages[safe: newValue] }
    }

    init() {}
  }

  enum Action: BindableAction {
    case alert(PresentationAction<Alert>)
    case binding(BindingAction<State>)
    case task

    case modelSelector(ModelSelector.Action)
    case subscriptionSection(SubscriptionSection.Action)

    case deleteStorageTapped
    case openGitHub
    case openPersonalWebsite
    case rateAppTapped
    case reportBugTapped
    case showError(EquatableError)
    case suggestFeatureTapped
    case updateInfo
    case updateIsSubscribed(Bool)

    enum Alert: Equatable {
      case deleteDialogConfirmed
    }
  }

  @Dependency(\.openURL) var openURL: OpenURLEffect
  @Dependency(\.build) var build: BuildClient
  @Dependency(StorageClient.self) var storage: StorageClient
  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.subscriptionSection, action: /Action.subscriptionSection) {
      SubscriptionSection()
    }

    Scope(state: \.modelSelector, action: /Action.modelSelector) {
      ModelSelector()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .modelSelector:
        return .none

      case .subscriptionSection:
        return .none

      case .task:
        updateInfo(state: &state)
        return .run { send in
          do {
            let isSubscribed = try await subscriptionClient.checkIfSubscribed()
            await send(.updateIsSubscribed(isSubscribed))
          } catch {
            await send(.showError(error.equatable))
          }
          for await isSubscribed in subscriptionClient.isSubscribedStream() {
            await send(.updateIsSubscribed(isSubscribed))
          }
        }

      case .updateInfo:
        updateInfo(state: &state)
        return .send(.modelSelector(.reloadModels))

      case .openGitHub:
        return .run { _ in
          await openURL(build.githubURL())
        }

      case .openPersonalWebsite:
        return .run { _ in
          await openURL(build.personalWebsiteURL())
        }

      case .deleteStorageTapped:
        createDeleteConfirmationDialog(state: &state)
        return .none

      case .alert(.presented(.deleteDialogConfirmed)):
        state.settings.selectedModelName = WhisperKit.recommendedModels().default
        return .run { send in
          try await storage.deleteStorage()
          await send(.updateInfo)
        } catch: { error, send in
          await send(.showError(error.equatable))
        }

      case let .showError(error):
        state.alert = .error(error)
        return .none

      case .rateAppTapped:
        return .run { _ in
          await openURL(build.appStoreReviewURL())
        }

      case .reportBugTapped:
        return .run { _ in
          await openURL(build.bugReportURL())
        }

      case .suggestFeatureTapped:
        return .run { _ in
          await openURL(build.featureRequestURL())
        }

      case let .updateIsSubscribed(isSubscribed):
        state.isSubscribed = isSubscribed
        return .none

      case .alert:
        return .none
      }
    }.ifLet(\.$alert, action: /Action.alert)
  }

  private func updateInfo(state: inout State) {
    state.appVersion = build.version()
    state.buildNumber = build.buildNumber()
    state.freeSpace = storage.freeSpace().readableString
    state.takenSpace = storage.takenSpace().readableString
    state.takenSpacePercentage = min(1, max(0, 1 - Double(storage.freeSpace()) / Double(storage.freeSpace() + storage.takenSpace())))
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
