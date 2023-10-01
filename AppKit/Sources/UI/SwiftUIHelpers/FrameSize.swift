import SwiftUI

private let randomColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .white, .gray]

extension View {
  func frameSize(color: Color? = nil, alignment: Alignment = .topTrailing, line: UInt = #line) -> some View {
    modifier(FrameModifier(color: color ?? randomColors[Int(line) % randomColors.count], alignment: alignment))
  }

  func framePosition(color: Color? = nil, alignment: Alignment = .topTrailing, space: CoordinateSpace = .global, line: UInt = #line) -> some View {
    modifier(FrameModifier(color: color ?? randomColors[Int(line) % randomColors.count], alignment: alignment, space: space))
  }
}

// MARK: - FrameModifier

private struct FrameModifier: ViewModifier {
  var color: Color
  var alignment: Alignment
  var space: CoordinateSpace?

  func body(content: Content) -> some View {
    content
      .overlay(GeometryReader(content: overlay(for:)))
  }

  func overlay(for geometry: GeometryProxy) -> some View {
    ZStack(alignment: alignment) {
      Rectangle()
        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
        .foregroundColor(color)

      var text: String {
        if let space {
          let origin = geometry.frame(in: space).origin
          return "x: \(Int(origin.x)) y: \(Int(origin.y))"
        } else {
          return "\(Int(geometry.size.width))x\(Int(geometry.size.height))"
        }
      }

      Text(text)
        .font(.caption2)
        .foregroundColor(color)
        .padding(2)
    }
  }
}
