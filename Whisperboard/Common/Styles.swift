//
// Styles.swift
//

import SwiftUI

// MARK: - MyButtonStyle

struct MyButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .padding()
      .background(Color(UIColor.systemGray3))
      .foregroundColor(Color(UIColor.label))
      .cornerRadius(5)
      .shadow(color: Color(UIColor.systemGray6), radius: 0.5, x: 0, y: 1)
      .overlay {
        ZStack {
          if configuration.isPressed {
            Color.black.opacity(0.5)
          }
        }
      }
  }
}

// MARK: - PrimaryCardStyle

public struct PrimaryCardStyle: ViewModifier {
  public func body(content: Content) -> some View {
    content.background {
      ZStack {
        RoundedRectangle(cornerRadius: .grid(3))
          .fill(LinearGradient.cardBackground)

        RoundedRectangle(cornerRadius: .grid(3))
          .strokeBorder(LinearGradient.cardBorder, lineWidth: 1)
      }
      .compositingGroup()
      .shadow(color: .Palette.Shadow.base, radius: 15, x: 0, y: 5)
    }
  }
}

public extension View {
  func primaryCardStyle() -> some View {
    modifier(PrimaryCardStyle())
  }
}
