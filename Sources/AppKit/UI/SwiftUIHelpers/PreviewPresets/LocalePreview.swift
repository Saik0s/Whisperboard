import SwiftUI

// MARK: - LocalePreview

struct LocalePreview<Preview: View>: View {
  private let preview: Preview

  var body: some View {
    ForEach(Locale.all, id: \.self) { locale in
      preview
        .previewLayout(PreviewLayout.sizeThatFits)
        .environment(\.locale, locale)
        .previewDisplayName("Locale: \(locale.identifier)")
    }
  }

  init(@ViewBuilder builder: @escaping () -> Preview) {
    preview = builder()
  }
}

/// From https://www.avanderlee.com/swiftui/previews-different-states/
extension Locale {
  static let all = Bundle.main.localizations.map(Locale.init).filter { $0.identifier != "base" }
}
