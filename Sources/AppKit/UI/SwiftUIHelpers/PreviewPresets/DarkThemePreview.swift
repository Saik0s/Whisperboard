import SwiftUI

struct DarkThemePreview<Preview: View>: View {
  private let preview: Preview

  var body: some View {
    preview
      .previewLayout(PreviewLayout.sizeThatFits)
      .background(Color.black)
      .environment(\.colorScheme, .dark)
      .previewDisplayName("Dark Theme")
  }

  init(@ViewBuilder builder: @escaping () -> Preview) {
    preview = builder()
  }
}
