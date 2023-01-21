import CoreGraphics

public extension CGFloat {
  static func grid(_ factor: Int) -> Self { Self(factor) * 4 }
}
