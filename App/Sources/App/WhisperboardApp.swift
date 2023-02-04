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
    Color.DS.Background.primary = Color(DynamicColor(hexString: "#1D1820"))
    Color.DS.Background.secondary = Color(DynamicColor(hexString: "#2C2634"))
    Color.DS.Background.tertiary = Color(DynamicColor(hexString: "#4E4857"))
    Color.DS.Background.accent = Color(DynamicColor(hexString: "#F85616"))
    Color.DS.Background.accentAlt = Color(DynamicColor(hexString: "#B11EF6"))

    Color.DS.Text.base = Color(DynamicColor(hexString: "#FFFFFF"))
    Color.DS.Text.subdued = Color(DynamicColor(hexString: "#5E6272"))
    Color.DS.Text.accent = Color(DynamicColor(hexString: "#F85616"))
    Color.DS.Text.accentAlt = Color(DynamicColor(hexString: "#abe4fd"))

    Font.DS.date = .system(.caption, design: .monospaced).weight(.medium)
    Font.DS.captionM = .system(.caption, design: .rounded).weight(.medium)
  }
}
