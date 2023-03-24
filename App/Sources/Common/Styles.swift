import AppDevUtils
import SwiftUI

// MARK: - PrimaryButtonStyle

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.DS.headlineM)
      .foregroundColor(.DS.Text.base)
      .padding(.grid(2))
      .padding(.horizontal, .grid(2))
      .background {
        Color.DS.Background.accent
          .continuousCornerRadius(.grid(2))
          .shadow(color: Color.DS.Background.accent.opacity(configuration.isPressed ? 0 : 0.7), radius: 4, x: 0, y: 0)
      }
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
  }
}

extension View {
  func primaryButtonStyle() -> some View {
    buttonStyle(PrimaryButtonStyle())
  }
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
  let action: () -> Void
  let label: String

  init(_ label: String, action: @escaping () -> Void) {
    self.label = label
    self.action = action
  }

  var body: some View {
    Button(label, action: action)
      .primaryButtonStyle()
  }
}

struct IconButtonStyle: ButtonStyle {
  var color: Color = .DS.Text.accent

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .foregroundColor(color)
      .font(.DS.titleM)
      .fontWeight(.light)
      .padding(.grid(1))
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
  }
}

extension View {
  func iconButtonStyle() -> some View {
    buttonStyle(IconButtonStyle(color: .DS.Text.accent))
  }

  func secondaryIconButtonStyle() -> some View {
    buttonStyle(IconButtonStyle(color: .DS.Text.base))
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
