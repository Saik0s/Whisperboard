import SwiftUI

// Example:
//
// var body: some View {
//  childView
//    .readSize { newSize in
//      print("The new child size is: \(newSize)")
//    }
// }
//

extension View {
  func readFrame(ignoringZero: Bool = false, onChange: @escaping (CGRect) -> Void) -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .preference(key: FramePreferenceKey.self, value: geometryProxy.frame(in: .global))
      }
    )
    .onPreferenceChange(FramePreferenceKey.self) { rect in
      if ignoringZero && rect == .zero {
        return
      } else {
        onChange(rect)
      }
    }
  }

  func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
      }
    )
    .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
  }

  func readPosition(onChange: @escaping (CGPoint) -> Void) -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .preference(key: PositionPreferenceKey.self, value: geometryProxy.frame(in: .global).origin)
      }
    )
    .onPreferenceChange(PositionPreferenceKey.self, perform: onChange)
  }

  func readSafeArea(onChange: @escaping (EdgeInsets) -> Void) -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .preference(key: SafeAreaPreferenceKey.self, value: geometryProxy.safeAreaInsets)
      }
    )
    .onPreferenceChange(SafeAreaPreferenceKey.self, perform: onChange)
  }
}

// MARK: - FramePreferenceKey

private struct FramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .zero

  static func reduce(value _: inout CGRect, nextValue _: () -> CGRect) {}
}

// MARK: - SizePreferenceKey

private struct SizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero

  static func reduce(value _: inout CGSize, nextValue _: () -> CGSize) {}
}

// MARK: - PositionPreferenceKey

private struct PositionPreferenceKey: PreferenceKey {
  static var defaultValue: CGPoint = .zero

  static func reduce(value _: inout CGPoint, nextValue _: () -> CGPoint) {}
}

// MARK: - SafeAreaPreferenceKey

private struct SafeAreaPreferenceKey: PreferenceKey {
  static var defaultValue: EdgeInsets = .init()

  static func reduce(value _: inout EdgeInsets, nextValue _: () -> EdgeInsets) {}
}
