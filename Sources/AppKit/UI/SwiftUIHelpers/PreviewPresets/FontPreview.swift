import SwiftUI

struct FontPreview<Preview: View>: View {
  private let preview: Preview
  private let font: Font

  var body: some View {
    preview
      .previewLayout(PreviewLayout.sizeThatFits)
      .environment(\.font, font)
      .previewDisplayName("Font")
  }

  init(_ font: Font, @ViewBuilder builder: @escaping () -> Preview) {
    self.font = font
    preview = builder()
  }
}
