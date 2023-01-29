import AppDevUtils
import SwiftUI

// MARK: - MyButtonStyle

struct MyButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.DS.bodyM)
      .padding(.grid(2))
      .background(Color.DS.Background.accent)
      .foregroundColor(Color.DS.Text.base)
      .cornerRadius(5)
      .shadow(color: Color.DS.Shadow.primary, radius: 0.5, x: 0, y: 1)
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
          LinearGradient.easedGradient(colors: [
            .DS.Background.tertiary.lighten(by: 0.05),
            .DS.Background.tertiary,
          ], startPoint: .topLeading, endPoint: .bottomTrailing)

          LinearGradient.easedGradient(colors: [
            .DS.Background.secondary.lighten(by: 0.1),
            .DS.Background.secondary,
          ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .opacity(isPrimary ? 1 : 0)
        }
        .cornerRadius(.grid(4))
        .shadow(color: isPrimary ? .DS.Shadow.primary : .DS.Shadow.secondary,
                radius: isPrimary ? 50 : 15,
                x: 0,
                y: isPrimary ? 7 : 3)
      }
      .background {
        ZStack {
          RoundedRectangle(cornerRadius: .grid(4))
            .strokeBorder(
              isPrimary
                ? LinearGradient.cardPrimaryBorder
                : LinearGradient.cardSecondaryBorder,
              lineWidth: 1
            )
            .opacity(0.5)
        }
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
