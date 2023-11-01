import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import DynamicColor
import SwiftUI

// MARK: - AppView

public struct AppView: View {
  public init() {
    appSetup()
  }

  public var body: some View {
    RootView(store: Store(initialState: Root.State()) {
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
//        ._printChanges(.swiftLog())
      #endif
    })
  }
}

func appSetup() {
  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  transcriptionWorker.registerForProcessingTask()

  @Dependency(\.keychainClient) var keychainClient: KeychainClient

  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient
  subscriptionClient.configure(keychainClient.userID)

  #if DEBUG
    LoggerWrapper.Settings.destinations = [
      .print,
      .custom(format: "%d %t %F:%l %f %m") { _, text in
        DispatchQueue.global(qos: .utility).async {
          do {
            let fileHandle = try FileHandle(forWritingTo: Configs.logFileURL)
            fileHandle.seekToEndOfFile()
            fileHandle.write(text.data(using: .utf8)!)
            fileHandle.closeFile()
          } catch {
            FileManager.default.createFile(atPath: Configs.logFileURL.path, contents: text.data(using: .utf8), attributes: nil)
            do {
              try text.write(toFile: Configs.logFileURL.path, atomically: true, encoding: .utf8)
            } catch {
              print(error)
            }
          }
        }
      },
    ]
  #endif
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
