
import ComposableArchitecture
import Inject
import Popovers
import SwiftUI
import SwiftUIIntrospect

// MARK: - SettingsScreen

struct SettingsScreen: ReducerProtocol {
  struct State: Equatable {
    @BindingState var settings: Settings = .init()
    var modelSelector = ModelSelector.State()
    var subscriptionSection: SubscriptionSection.State = .init()

    var availableLanguages: IdentifiedArrayOf<VoiceLanguage> = []
    var appVersion: String = ""
    var buildNumber: String = ""
    var freeSpace: String = ""
    var takenSpace: String = ""
    var takenSpacePercentage: Double = 0
    var isSubscribed: Bool = false

    @BindingState var isICloudSyncInProgress = false
    @BindingState var isDebugLogPresented = false
    @BindingState var isModelSelectorPresented = false

    @PresentationState var alert: AlertState<Action.Alert>?
  }

  enum Action: BindableAction, Equatable {
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

  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  @Dependency(\.settings) var settingsClient: SettingsClient
  @Dependency(\.openURL) var openURL: OpenURLEffect
  @Dependency(\.build) var build: BuildClient
  @Dependency(\.storage) var storage: StorageClient
  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()
      .onChange(of: \.settings.isICloudSyncEnabled) { oldValue, newValue in
        Reduce<State, Action> { _, _ in
          if oldValue != newValue, newValue {
            return .run { send in
              if settingsClient.getSettings().isICloudSyncEnabled != newValue {
                await send(.set(\.$isICloudSyncInProgress, true))
                try await storage.uploadRecordingsToICloud(true)
                await send(.set(\.$isICloudSyncInProgress, false))
              }
              try await settingsClient.updateSettings(settingsClient.getSettings().with(\.isICloudSyncEnabled, setTo: newValue))
            } catch: { error, send in
              await send(.set(\.$isICloudSyncInProgress, false))
              await send(.set(\.$settings, settingsClient.getSettings()))
              await send(.showError(error.equatable))
            }
          } else {
            return .none
          }
        }
      }
      .onChange(of: \.settings.selectedModel) { _, _ in
        Reduce<State, Action> { _, _ in
          .send(.modelSelector(.reloadSelectedModel))
        }
      }

    Scope(state: \.subscriptionSection, action: /Action.subscriptionSection) {
      SubscriptionSection()
    }

    Scope(state: \.modelSelector, action: /Action.modelSelector) {
      ModelSelector()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .run { [settings = state.settings] _ in
          try await settingsClient.updateSettings(settings)
        } catch: { error, send in
          await send(.set(\.$settings, settingsClient.getSettings()))
          await send(.showError(error.equatable))
        }

      case .modelSelector:
        return .none

      case .subscriptionSection:
        return .none

      case .task:
        updateInfo(state: &state)
        return .run { send in
          for try await settings in settingsClient.settingsPublisher().values {
            await send(.set(\.$settings, settings))
          }
        } catch: { error, send in
          await send(.showError(error.equatable))
        }.merge(with: .run { send in
          do {
            let isSubscribed = try await subscriptionClient.checkIfSubscribed()
            await send(.updateIsSubscribed(isSubscribed))
          } catch {
            await send(.showError(error.equatable))
          }
          for await isSubscribed in subscriptionClient.isSubscribedStream() {
            await send(.updateIsSubscribed(isSubscribed))
          }
        })

      case .updateInfo:
        updateInfo(state: &state)
        state.modelSelector = .init()
        return .send(.modelSelector(.reloadSelectedModel))

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
        return .run { send in
          try await storage.deleteStorage()
          try await settingsClient.setValue(.default, forKey: \.selectedModel)
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
    state.availableLanguages = transcriptionWorker.getAvailableLanguages().identifiedArray
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
