import SwiftUI
import VariableBlurView
import ComposableArchitecture

// MARK: - AnimatedTabBar

struct AnimatedTabBar: View {
  @Binding var selectedIndex: Root.Tab

  var body: some View {
    HStack(spacing: 50) {
      TabBarButton(
        image: Image(systemName: "list.bullet"),
        isSelected: selectedIndex == .list
      ) {
        selectedIndex = .list
      }

      TabBarButton(
        image: Image(systemName: "mic"),
        isSelected: selectedIndex == .record
      ) {
        selectedIndex = .record
      }
      .opacity(selectedIndex == .record ? 0 : 1)
      .disabled(selectedIndex == .record)

      TabBarButton(
        image: Image(systemName: "gear"),
        isSelected: selectedIndex == .settings
      ) {
        selectedIndex = .settings
      }
    }
    .padding(.horizontal)
    .background(TabBarBackground(selectedIndex: selectedIndex))
    .padding()
    .frame(maxWidth: .infinity)
    .background {
      VariableBlurView(maxBlurRadius: 10)
        .rotationEffect(.degrees(180), anchor: .center)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
  }
}

// MARK: - TabBarBackground

struct TabBarBackground: View {
  enum AnimationStage: Hashable {
    case base, toCircle, up
  }

  var selectedIndex: Root.Tab

  @State var animationStage: AnimationStage = .up
  let baseColor = Color.DS.Background.secondary
  let circleColor = Color.DS.Background.accent
  let circleWidth: CGFloat = 70

  @Environment(RecordButtonModel.self) var recordButtonModel: RecordButtonModel
  @Environment(NamespaceContainer.self) var namespace

  var body: some View {
    WithPerceptionTracking {
      ZStack {
        if animationStage != .up {
          Capsule(style: .continuous)
            .foregroundColor(animationStage == .base ? baseColor : circleColor)
            .frame(width: animationStage == .base ? nil : circleWidth)
            .frame(height: 70)
            .matchedGeometryEffect(id: "mic", in: namespace.namespace)
        }
      }
      .onChange(of: selectedIndex) { selectedIndex in
        triggerAnimation(selectedIndex)
      }
    }
  }

  private func triggerAnimation(_ selectedIndex: Root.Tab) {
    if selectedIndex == .record && animationStage == .base {
      withAnimation(.showHide()) {
        animationStage = .toCircle
      }
      withAnimation(.showHide().delay(0.15)) {
        animationStage = .up
        recordButtonModel.isExpanded = true
      }
    } else if animationStage == .up {
      withAnimation(.showHide()) {
        animationStage = .toCircle
        recordButtonModel.isExpanded = false
      }
      withAnimation(.showHide().delay(0.15)) {
        animationStage = .base
      }
    } else {
      animationStage = selectedIndex == .record ? .up : .base
      recordButtonModel.isExpanded = selectedIndex == .record
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
        .font(.DS.title)
        .foregroundColor(isSelected ? Color.DS.Text.accent : Color.DS.Text.base)
        .fontWeight(isSelected ? .semibold : .light)
        .shadow(color: Color.DS.Text.accent.opacity(isSelected ? 0.2 : 0), radius: 10, x: 0, y: 0)
        .frame(width: 30, height: 30)
        .padding()
        .contentShape(Rectangle())
    }
    .buttonStyle(TabBarButtonStyle())
    .animation(.gentleBounce(), value: isSelected)
  }
}

// MARK: - TabBarButtonStyle

struct TabBarButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.8 : 1)
      .animation(.gentleBounce(), value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { _ in
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      }
  }
}
