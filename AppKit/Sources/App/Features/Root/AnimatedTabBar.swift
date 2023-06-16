import SwiftUI
import VariableBlurView

// MARK: - CustomTabBar

struct CustomTabBar: View {
  @Binding var selectedIndex: Int
  var animation: Namespace.ID

  var body: some View {
    HStack {
      TabBarButton(icon: "list.bullet", action: {
        selectedIndex = 0
      })
      Spacer()
      TabBarButton(icon: "circle.inset.filled", action: {
        selectedIndex = 1
      }).opacity(selectedIndex == 1 ? 0 : 1)
      Spacer()
      TabBarButton(icon: "gear", action: {
        selectedIndex = 2
      })
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(TabBarBackground(selectedIndex: selectedIndex, animation: animation))
    .padding()
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
        .scaleEffect(animationStage == .up ? scale : 1)
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
  var icon: String
  var action: () -> Void
  let textColor = Color.white
  let iconFont = Font.title

  var body: some View {
    Button(action: action) {
      Label("", systemImage: icon).foregroundColor(textColor).font(iconFont)
    }
    .frame(maxWidth: .infinity)
  }
}
