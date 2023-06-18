import SwiftUI
import VariableBlurView

// MARK: - AnimatedTabBar

struct AnimatedTabBar: View {
  @Binding var selectedIndex: Int
  var animation: Namespace.ID

  var body: some View {
    HStack(spacing: 50) {
      TabBarButton(
        image: Image(systemName: "list.bullet"),
        isSelected: selectedIndex == 0
      ) {
        selectedIndex = 0
      }

      TabBarButton(
        image: Image(systemName: "mic"),
        isSelected: selectedIndex == 1
      ) {
        selectedIndex = 1
      }.opacity(selectedIndex == 1 ? 0 : 1)

      TabBarButton(
        image: Image(systemName: "gear"),
        isSelected: selectedIndex == 2
      ) {
        selectedIndex = 2
      }
    }
    .padding(.horizontal, 50)
    .background(TabBarBackground(selectedIndex: selectedIndex, animation: animation))
    .padding()
    .frame(maxWidth: .infinity)
    .background {
      VariableBlurView()
        .rotationEffect(.degrees(180), anchor: .center)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
  }
}

// MARK: - TabBarBackground

struct TabBarBackground: View {
  var selectedIndex: Int = 0
  var animation: Namespace.ID
  @State var animationStage: AnimationStage = .base
  let baseColor = Color.DS.Background.secondary
  let circleColor = Color.DS.Background.accent
  let micImage = AnyView(Image(systemName: "mic").font(.title))
  let yOffset: CGFloat = -70
  let circleWidth: CGFloat = 70
  let scale: CGFloat = 1.3

  enum AnimationStage: Hashable {
    case base, toCircle, up
  }

  var body: some View {
    ZStack {
      Capsule(style: .continuous)
        .foregroundColor(animationStage == .base ? baseColor : circleColor)
        .overlay(animationStage == .base ? nil : micImage)
        .offset(x: 0, y: animationStage == .up ? yOffset : 0)
        .frame(width: animationStage == .base ? nil : circleWidth)
        .scaleEffect(animationStage == .up ? scale : (animationStage == .toCircle ? 0.1 : 1))
        .opacity(animationStage == .up ? 0 : 1)
    }
    .frame(height: 70)
    .onChange(of: selectedIndex) { selectedIndex in
      if selectedIndex == 1 {
        withAnimation(.spring().speed(3)) {
          animationStage = .toCircle
        }
        withAnimation(.spring().speed(3).delay(0.2)) {
          animationStage = .up
        }
      } else if animationStage == .up {
        withAnimation(.spring().speed(3)) {
          animationStage = .toCircle
        }
        withAnimation(.spring().speed(3).delay(0.2)) {
          animationStage = .base
        }
      } else {
        animationStage = .base
      }
    }
  }
}

// MARK: - TabBarButton

struct TabBarButton: View {
  var image: Image
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      image
        .resizable()
        .renderingMode(.template)
        .fontWeight(isSelected ? .medium : .regular)
        .foregroundColor(isSelected ? Color.DS.Text.accent : Color.DS.Text.base)
        .scaledToFit()
        .frame(width: 30, height: 30)
        .padding()
        .contentShape(Rectangle())
    }
    .buttonStyle(TabBarButtonStyle())
    .animation(.spring(), value: isSelected)
  }
}

// MARK: - TabBarButtonStyle

struct TabBarButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.8 : 1)
      .animation(.spring(), value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { isPressed in
        if isPressed {
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
      }
  }
}
