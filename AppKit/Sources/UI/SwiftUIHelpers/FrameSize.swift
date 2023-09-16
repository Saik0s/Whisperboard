import SwiftUI

private let randomColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .white, .gray]

extension View {
  func frameSize(color: Color? = nil, alignment: Alignment = .topTrailing, line: UInt = #line) -> some View {
    modifier(FrameSize(color: color ?? randomColors[Int(line) % randomColors.count], alignment: alignment))
  }

  func framePosition(color: Color? = nil, alignment: Alignment = .topTrailing, space: CoordinateSpace = .global, line: UInt = #line) -> some View {
    modifier(FramePosition(color: color ?? randomColors[Int(line) % randomColors.count], alignment: alignment, space: space))
  }
}

// MARK: - FrameSize

private struct FrameSize: ViewModifier {
  var color: Color
  var alignment: Alignment

  func body(content: Content) -> some View {
    content
      .overlay(GeometryReader(content: overlay(for:)))
  }

  func overlay(for geometry: GeometryProxy) -> some View {
    ZStack(alignment: alignment) {
      Rectangle()
        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
        .foregroundColor(color)

      Text("\(Int(geometry.size.width))x\(Int(geometry.size.height))")
        .font(.caption2)
        .foregroundColor(color)
        .padding(2)
    }
  }
}

// MARK: - FramePosition

private struct FramePosition: ViewModifier {
  var color: Color
  var alignment: Alignment
  var space: CoordinateSpace

  func body(content: Content) -> some View {
    content
      .overlay(GeometryReader(content: overlay(for:)))
  }

  func overlay(for geometry: GeometryProxy) -> some View {
    ZStack(alignment: alignment) {
      Rectangle()
        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
        .foregroundColor(color)

      let origin = geometry.frame(in: .global).origin
      Text("x: \(Int(origin.x)) y: \(Int(origin.y))")
        .font(.caption2)
        .foregroundColor(color)
        .padding(2)
    }
  }
}
