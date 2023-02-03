import AppDevUtils
import ComposableArchitecture
import DynamicColor
import SwiftUI

@main
struct WhisperboardApp: App {
  var body: some Scene {
    WindowGroup {
      RootView(
        store: Store(
          initialState: Root.State(),
          reducer: Root()
        )
      )
    }
  }

  init() {
    configureDesignSystem()

    Logger.Settings.format = "%C%t %F:%l %m%c"
  }

  private func configureDesignSystem() {
    Color.DS.Background.primary = Color(DynamicColor(hexString: "#202437"))
    Color.DS.Background.secondary = .DS.Background.primary.lighten(by: 0.05)
    Color.DS.Background.tertiary = .DS.Background.primary.darken(by: 0.05)
    Color.DS.Background.accent = Color(DynamicColor(hexString: "#fb3d02"))
    Color.DS.Background.accentAlt = Color(DynamicColor(hexString: "#45202f"))

    Color.DS.Text.base = Color(DynamicColor(hexString: "#FFFFFF"))
    Color.DS.Text.subdued = Color(DynamicColor(hexString: "#858FB7"))
    Color.DS.Text.accent = Color(DynamicColor(hexString: "#fb3d02"))
    Color.DS.Text.accentAlt = Color(DynamicColor(hexString: "#FFFFFF"))

    Font.DS.date = .system(.caption, design: .monospaced).weight(.medium)
  }
}
