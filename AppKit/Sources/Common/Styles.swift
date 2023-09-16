import Inject
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
        LinearGradient.easedGradient(colors: [
          Color.DS.Background.accent.lighten(by: 0.03),
          Color.DS.Background.accent.darken(by: 0.07),
          Color.DS.Background.accent.darken(by: 0.1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
          .continuousCornerRadius(.grid(2))
          .shadow(color: Color.DS.Background.accent.darken(by: 0.2).opacity(configuration.isPressed ? 0 : 0.7), radius: 4, x: 0, y: 0)
      }
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.gentleBounce(), value: configuration.isPressed)
  }
}

extension View {
  func primaryButtonStyle() -> some View {
    buttonStyle(PrimaryButtonStyle())
  }
}

// MARK: - SecondaryButtonStyle

struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.DS.headlineM)
      .foregroundColor(.DS.Text.base)
      .padding(.grid(2))
      .padding(.horizontal, .grid(2))
      .background {
        LinearGradient.easedGradient(colors: [
          Color.DS.Background.accentAlt.lighten(by: 0.03),
          Color.DS.Background.accentAlt.darken(by: 0.07),
          Color.DS.Background.accentAlt.darken(by: 0.1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
          .continuousCornerRadius(.grid(2))
          .shadow(color: Color.DS.Background.accentAlt.darken(by: 0.2).opacity(configuration.isPressed ? 0 : 0.7), radius: 4, x: 0, y: 0)
      }
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.gentleBounce(), value: configuration.isPressed)
  }
}

extension View {
  func secondaryButtonStyle() -> some View {
    buttonStyle(SecondaryButtonStyle())
  }
}

// MARK: - TertiaryButtonStyle

struct TertiaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.DS.headlineS)
      .foregroundColor(.DS.Text.accent)
      .padding(.grid(2))
      .padding(.horizontal, .grid(2))
      .background {
        Color.DS.Background.accent.opacity(0.2)
          .continuousCornerRadius(.grid(2))
      }
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.gentleBounce(), value: configuration.isPressed)
  }
}

extension View {
  func tertiaryButtonStyle() -> some View {
    buttonStyle(TertiaryButtonStyle())
  }
}

// MARK: - IconButtonStyle

struct IconButtonStyle: ButtonStyle {
  var isPrimary: Bool = true
  @State var feedbackGenerator = UISelectionFeedbackGenerator()

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .foregroundColor(isPrimary ? .DS.Text.accent : .DS.Text.base)
      .font(isPrimary ? .DS.headlineS : .DS.bodyM)
      .frame(width: 30, height: 30)
      .padding(.grid(2))
      .scaleEffect(configuration.isPressed ? 0.9 : 1)
      .contentShape(Rectangle())
      .animation(.gentleBounce(), value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { _ in
        feedbackGenerator.selectionChanged()
      }
  }
}

extension View {
  func iconButtonStyle() -> some View {
    buttonStyle(IconButtonStyle(isPrimary: true))
  }

  func secondaryIconButtonStyle() -> some View {
    buttonStyle(IconButtonStyle(isPrimary: false))
  }
}

// MARK: - CardButtonStyle

struct CardButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
    // .scaleEffect(configuration.isPressed ? 0.95 : 1)
  }
}

extension View {
  func cardButtonStyle() -> some View {
    buttonStyle(CardButtonStyle())
  }
}

// MARK: - RecordButtonStyle

struct RecordButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.gentleBounce(), value: configuration.isPressed)
  }
}

extension View {
  func recordButtonStyle() -> some View {
    buttonStyle(RecordButtonStyle())
  }
}

// MARK: - CardStyle

struct CardStyle: ViewModifier {
  @ObserveInjection var inject

  var isPrimary: Bool

  func body(content: Content) -> some View {
    content
      .cornerRadius(.grid(4))
      .background {
        ZStack {
          LinearGradient.easedGradient(colors: [
            .DS.Background.secondary,
            .DS.Background.secondary.darken(by: 0.02),
            .DS.Background.secondary.darken(by: 0.04),
          ], startPoint: .topLeading, endPoint: .bottom)

          LinearGradient.easedGradient(colors: [
            .DS.Background.secondary.lighten(by: 0.07),
            .DS.Background.secondary,
          ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .opacity(isPrimary ? 1 : 0)

          Color.DS.Background.accentAlt.blendMode(.multiply)
            .opacity(isPrimary ? 0.3 : 0)

          RoundedRectangle(cornerRadius: .grid(4))
            .strokeBorder(
              LinearGradient.easedGradient(colors: [
                .DS.Background.secondary.lighten(by: 0.01),
                .DS.Background.secondary,
              ], startPoint: .topLeading, endPoint: .bottom),
              lineWidth: 1
            )
            .opacity(isPrimary ? 0 : 1)

          RoundedRectangle(cornerRadius: .grid(4))
            .strokeBorder(
              LinearGradient.easedGradient(colors: [
                .DS.Background.secondary.lighten(by: 0.08),
                .DS.Background.secondary.lighten(by: 0.02),
              ], startPoint: .topLeading, endPoint: .bottomTrailing),
              lineWidth: 1
            )
            .opacity(isPrimary ? 1 : 0)
        }
        .cornerRadius(.grid(4))
        .shadow(color: .DS.Background.accentAlt.darken(by: 0.4).opacity(isPrimary ? 1 : 0),
                radius: isPrimary ? 50 : 5,
                x: 0,
                y: isPrimary ? 7 : 1)
      }
  }
}

extension View {
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
