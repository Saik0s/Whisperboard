import SwiftUI

extension View {
  func previewSupportedLocales() -> some View {
    LocalePreview { self }
  }

  func previewDarkTheme() -> some View {
    DarkThemePreview { self }
  }

  func previewRightToLeft() -> some View {
    RightToLeftPreview { self }
  }

  func previewContentSize(_ sizeCategory: ContentSizeCategory) -> some View {
    ContentSizeCategoryPreview(sizeCategory) { self }
  }
}

extension View {
  func previewAllPresets() -> some View {
    let content = padding()
      .background(Color.black.ignoresSafeArea())
      .environment(\.colorScheme, .dark)

    return Group {
      content.previewSupportedLocales()
      content.previewRightToLeft()
      content.previewContentSize(.extraSmall)
      content.previewContentSize(.medium)
      content.previewContentSize(.extraExtraExtraLarge)
    }
  }

  func previewBasePreset() -> some View {
    ZStack {
      Color(.systemBackground).ignoresSafeArea()
      padding()
    }
    .environment(\.colorScheme, .dark)
  }
}
