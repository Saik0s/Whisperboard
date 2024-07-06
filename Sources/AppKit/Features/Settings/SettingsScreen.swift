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
    var premiumFeaturesSection: PremiumFeaturesSection.State = .init()

    let availableLanguages: [String] = ["Auto"] + Constants.languages.keys.sorted()
    var appVersion: String = ""
    var buildNumber: String = ""
    var freeSpace: String = ""
    var takenSpace: String = ""
    var takenSpacePercentage: Double = 0
    var isSubscribed = false

    @Shared(.isICloudSyncInProgress) var isICloudSyncInProgress: Bool
    var isDebugLogPresented = false
    var isModelSelectorPresented = false

    @Presents var alert: AlertState<Action.Alert>?

    var selectedLanguageIndex: Int {
      get { settings.voiceLanguage.flatMap { availableLanguages.firstIndex(of: $0) } ?? 0 }
      set { settings.voiceLanguage = newValue == 0 ? nil : availableLanguages[safe: newValue] }
    }

    init() {}
  }

  enum Action: BindableAction {
    case alert(PresentationAction<Alert>)
    case binding(BindingAction<State>)
    case task

    case modelSelector(ModelSelector.Action)
    case subscriptionSection(SubscriptionSection.Action)
    case premiumFeaturesSection(PremiumFeaturesSection.Action)

    case deleteStorageTapped
    case deleteAllModelsTapped
    case openGitHub
    case openPersonalWebsite
    case rateAppTapped
    case reportBugTapped
    case showError(EquatableError)
    case suggestFeatureTapped
    case updateInfo
    case updateIsSubscribed(Bool)

    enum Alert: Equatable {
      case deleteStorageDialogConfirmed
      case deleteAllModelsDialogConfirmed
    }
  }

  @Dependency(\.openURL) var openURL: OpenURLEffect
  @Dependency(\.build) var build: BuildClient
  @Dependency(StorageClient.self) var storage: StorageClient
  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.subscriptionSection, action: \.subscriptionSection) {
      SubscriptionSection()
    }

    Scope(state: \.modelSelector, action: \.modelSelector) {
      ModelSelector()
    }

    Scope(state: \.premiumFeaturesSection, action: \.premiumFeaturesSection) {
      PremiumFeaturesSection()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .modelSelector:
        return .none

      case .subscriptionSection:
        return .none

      case .premiumFeaturesSection:
        return .none

      case .task:
        updateInfo(state: &state)
        return .none
        // return .run { send in
        //   do {
        //     let isSubscribed = try await subscriptionClient.checkIfSubscribed()
        //     await send(.updateIsSubscribed(isSubscribed))
        //   } catch {
        //     await send(.showError(error.equatable))
        //   }
        //   for await isSubscribed in subscriptionClient.isSubscribedStream() {
        //     await send(.updateIsSubscribed(isSubscribed))
        //   }
        // }

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
        state.alert = .deleteStorage
        return .none

      case .deleteAllModelsTapped:
        state.alert = .deleteAllModels
        return .none

      case .alert(.presented(.deleteStorageDialogConfirmed)):
        state.settings.selectedModelName = WhisperKit.recommendedModels().default
        return .run { send in
          try await storage.deleteStorage()
          await send(.updateInfo)
        } catch: { error, send in
          await send(.showError(error.equatable))
        }

      case .alert(.presented(.deleteAllModelsDialogConfirmed)):
        state.settings.selectedModelName = WhisperKit.recommendedModels().default
        return .run { send in
          try? FileManager.default.removeItem(at: TranscriptionStream.modelDirURL)
          try? FileManager.default.removeItem(at: .documentsDirectory.appendingPathComponent("models"))
          await send(.updateInfo)
          await send(.modelSelector(.reloadModels))
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
    }.ifLet(\.$alert, action: \.alert)
  }

  private func updateInfo(state: inout State) {
    state.appVersion = build.version()
    state.buildNumber = build.buildNumber()
    state.freeSpace = storage.freeSpace().readableString
    state.takenSpace = storage.takenSpace().readableString
    state.takenSpacePercentage = min(1, max(0, 1 - Double(storage.freeSpace()) / Double(storage.freeSpace() + storage.takenSpace())))
  }
}

extension AlertState where Action == SettingsScreen.Action.Alert {
  static var deleteStorage: AlertState {
    AlertState {
      TextState("Confirmation")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
      ButtonState(role: .destructive, action: .deleteStorageDialogConfirmed) {
        TextState("Delete")
      }
    } message: {
      TextState("Are you sure you want to delete all recordings?")
    }
  }

  static var deleteAllModels: AlertState {
    AlertState {
      TextState("Confirmation")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
      ButtonState(role: .destructive, action: .deleteAllModelsDialogConfirmed) {
        TextState("Delete")
      }
    } message: {
      TextState("Are you sure you want to delete all downloaded models?")
    }
  }
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<Settings>> {
  static var settings: Self {
    PersistenceKeyDefault(FileStorageKey<Settings>.settings, .init(selectedModelName: WhisperKit.recommendedModels().default))
  }
}
