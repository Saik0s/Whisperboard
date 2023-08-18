import AppDevUtils
import ComposableArchitecture
import Dependencies
import DynamicColor
import SwiftUI

// MARK: - AppView

public struct AppView: View {
  public init() {}

  public var body: some View {
    RootView(store: Store(initialState: Root.State(), reducer: Root()._printChanges(.actionLabels)))
  }
}

public func appSetup() {
  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  transcriptionWorker.registerForProcessingTask()
  configureDesignSystem()

  Logger.Settings.format = "%C%t %F:%l %m%c"

  #if DEBUG
    Logger.Settings.destinations += [.custom { _, text in
      DispatchQueue.global(qos: .utility).async {
        do {
          let fileHandle = try FileHandle(forWritingTo: Configs.logFileURL)
          fileHandle.seekToEndOfFile()
          fileHandle.write(text.data(using: .utf8)!)
          fileHandle.closeFile()
        } catch {
          print("Error appending to file: \(error)")
          FileManager.default.createFile(atPath: Configs.logFileURL.path, contents: text.data(using: .utf8), attributes: nil)
        }
      }
    }]
  #endif
}

private func configureDesignSystem() {
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
