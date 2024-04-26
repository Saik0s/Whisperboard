import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import DynamicColor
import RollbarNotifier
import SwiftUI

// MARK: - AppView

public struct AppView: View {
  @MainActor static let store = Store(initialState: Root.State()) {
    Root()
    #if DEBUG
      .dependency(\.storage, SettingsClient.liveValue.getSettings().useMockedClients ? .testValue : .liveValue)
      .transformDependency(\.transcriptionWorker) { worker in
        if SettingsClient.liveValue.getSettings().useMockedClients {
          worker.transcriptionStream = { [worker] in
            worker.transcriptionStream().filter { !$0.status.isError }.eraseToStream()
          }
        }
      }
      ._printChanges(.swiftLog())
    #endif
  }

  public init() {}

  public var body: some View {
    RootView(store: Self.store)
  }
}

public func appSetup() {
  #if APPSTORE
    let config = RollbarConfig.mutableConfig(withAccessToken: Secrets.ROLLBAR_ACCESS_TOKEN)
    Rollbar.initWithConfiguration(config)
  #endif

  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  transcriptionWorker.registerForProcessingTask()

  @Dependency(\.keychainClient) var keychainClient: KeychainClient

  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient
  subscriptionClient.configure(keychainClient.userID)
}

// MARK: - TestingAppView

public struct TestingAppView: View {
  public init() {
    appSetup()
  }

  public var body: some View {
    RootView(store: Store(initialState: Root.State()) {
      Root()
        .transformDependency(\.self) {
          $0.storage = .testValue
          $0.transcriptionWorker.transcriptionStream = { [worker = $0.transcriptionWorker] in
            worker.transcriptionStream().filter { !$0.status.isError }.eraseToStream()
          }
        }
        ._printChanges(.swiftLog())
    })
  }
}
