import AppDevUtils
import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import DynamicColor
import os
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
        ._printChanges(.actionLabels)
      #endif
    })
  }
}

public func appSetup() {
  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  transcriptionWorker.registerForProcessingTask()
  configureDesignSystem()

  Logger.Settings.format = "%C%t %F:%l %m%c"

  #if DEBUG
    let osLogger = os.Logger(
      subsystem: Bundle.main.bundleIdentifier!,
      category: "General"
    )
    Logger.Settings.destinations = [
      .custom { _, text in
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
      .custom { message, text in
        switch message.level {
        case .error:
          osLogger.error("\(text)")
        case .warning:
          osLogger.warning("\(text)")
        case .info:
          osLogger.info("\(text)")
        case .debug:
          osLogger.debug("\(text)")
        case .verbose:
          osLogger.log("\(text)")
        }
      },
    ]
  #endif
}

func configureDesignSystem() {
  Color.DS.Background.primary = Color(DynamicColor(hexString: "#1D1820"))
  Color.DS.Background.secondary = Color(DynamicColor(hexString: "#2C2634"))
  Color.DS.Background.tertiary = Color(DynamicColor(hexString: "#4E4857"))
  Color.DS.Background.accent = Color(DynamicColor(hexString: "#d60000"))
  Color.DS.Background.accentAlt = Color(DynamicColor(hexString: "#246BFD"))

  Color.DS.Text.base = Color(DynamicColor(hexString: "#FFFFFF"))
  Color.DS.Text.subdued = Color(DynamicColor(hexString: "#9195A8"))
  Color.DS.Text.accent = Color(DynamicColor(hexString: "#ff0831"))
  Color.DS.Text.accentAlt = Color(DynamicColor(hexString: "#abe4fd"))

  Font.DS.date = .system(.caption, design: .monospaced).weight(.medium)
  Font.DS.captionM = .system(.caption, design: .rounded).weight(.medium)
}
