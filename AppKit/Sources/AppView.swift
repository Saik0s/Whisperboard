
import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import DynamicColor
import SwiftUI


// MARK: - AppView

public struct AppView: View {
  public init() {}

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
      #endif
        ._printChanges(.swiftLog())
    })
  }
}

public func appSetup() {
  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  transcriptionWorker.registerForProcessingTask()

  #if DEBUG
    LoggerWrapper.Settings.destinations = [
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
              log.error(error)
            }
          }
        }
      },
    ]
  #endif
}
