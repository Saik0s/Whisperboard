import AsyncAlgorithms
import BackgroundTasks
import Combine
import ComposableArchitecture
import Dependencies
import DynamicColor
import RollbarNotifier
import SwiftUI

// MARK: - AppView

@MainActor
public struct AppView: View {
  public init() {}

  public var body: some View {
    RootView(store: Store(initialState: Root.State()) {
      Root()
      #if DEBUG
        ._printChanges(.swiftLog())
      #endif
    })
  }
}

public func appSetup() {
  #if APPSTORE
    let config = RollbarConfig.mutableConfig(withAccessToken: Secrets.ROLLBAR_ACCESS_TOKEN)
    Rollbar.initWithConfiguration(config)
  #endif

//  transcriptionWorker.registerForProcessingTask()

  BGTaskScheduler.shared.register(forTaskWithIdentifier: TranscriptionWorker.processingTaskIdentifier, using: nil) { task in
    guard let task = task as? BGProcessingTask else { return }
    @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
    transcriptionWorker.handleBGProcessingTask(bgTask: task)
  }
}

// MARK: - TestingAppView

public struct TestingAppView: View {
  public init() {
    appSetup()
  }

  public var body: some View {
    RootView(store: Store(initialState: Root.State()) {
      Root()
        ._printChanges(.swiftLog())
    })
  }
}
