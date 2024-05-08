import BackgroundTasks
import ComposableArchitecture
import RollbarNotifier
import SwiftUI

// MARK: - AppView

@MainActor
public struct AppView: View {
  @MainActor static let store = Store(initialState: Root.State()) {
    Root()
    #if DEBUG
      ._printChanges(.swiftLog(withStateChanges: true))
    #endif
  } withDependencies: {
    if ProcessInfo.processInfo.environment["UITesting"] == "true" {
      $0.defaultFileStorage = .inMemory
    }
  }

  public init() {
    #if APPSTORE
      let config = RollbarConfig.mutableConfig(withAccessToken: Secrets.ROLLBAR_ACCESS_TOKEN)
      Rollbar.initWithConfiguration(config)
    #endif

    BGTaskScheduler.shared.register(forTaskWithIdentifier: TranscriptionWorker.processingTaskIdentifier, using: nil) { task in
      guard let task = task as? BGProcessingTask else { return }
      Self.store.send(.registerForBGProcessingTasks(task))
    }
  }

  public var body: some View {
    RootView(store: Self.store)
  }
}

// MARK: - TestingAppView

public struct TestingAppView: View {
  public init() {}
  public var body: some View {
    RootView(store: Store(initialState: Root.State()) {
      Root()
        ._printChanges(.swiftLog())
    })
  }
}
