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

// MARK: - CardStyle

public struct CardStyle: ViewModifier {
  var isPrimary: Bool

  public func body(content: Content) -> some View {
    content
      .cornerRadius(.grid(4))
      .background {
      ZStack {
        Group {
          RoundedRectangle(cornerRadius: .grid(4))
            .fill(isPrimary
              ? LinearGradient.cardPrimaryBackground
              : LinearGradient.cardSecondaryBackground)

          RoundedRectangle(cornerRadius: .grid(4))
            .strokeBorder(
              isPrimary
                ? LinearGradient.cardPrimaryBorder
                : LinearGradient.cardSecondaryBorder,
              lineWidth: 1
            )
            .opacity(0.5)
        }
        .compositingGroup()
      }
      .shadow(color: isPrimary ? .Palette.Shadow.primary : .Palette.Shadow.secondary,
              radius: isPrimary ? 50 : 15,
              x: 0,
              y: isPrimary ? 7 : 3)
    }
  }
}

public extension View {
  func primaryCardStyle() -> some View {
    modifier(CardStyle(isPrimary: true))
  }

  func secondaryCardStyle() -> some View {
    modifier(CardStyle(isPrimary: false))
  }

  func cardStyle(isPrimary: Bool = true) -> some View {
    modifier(CardStyle(isPrimary: isPrimary))
  }
}
