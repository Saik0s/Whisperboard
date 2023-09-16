import SwiftUI

struct RightToLeftPreview<Preview: View>: View {
  private let preview: Preview

  var body: some View {
    preview
      .previewLayout(PreviewLayout.sizeThatFits)
      .environment(\.layoutDirection, .rightToLeft)
      .previewDisplayName("Right to Left")
  }

  init(@ViewBuilder builder: @escaping () -> Preview) {
    preview = builder()
  }
}
