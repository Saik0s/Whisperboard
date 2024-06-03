import Common
import ComposableArchitecture
import FluidGradient
import Inject
import SwiftUI
import VariableBlurView

// MARK: - TabBarViewModel

@Perceptible
class TabBarViewModel {
  var tabBarHeight: CGFloat = 94
  var isVisible = false

  init() {}
}

// MARK: - TabBarContainerView

struct TabBarContainerView<T1: View, T2: View, T3: View>: View {
  @Binding var selectedIndex: Root.Tab
  var screen1: T1
  var screen2: T2
  var screen3: T3

  @Environment(TabBarViewModel.self) private var tabBarViewModel: TabBarViewModel

  @State private var screenWidth: CGFloat = 0
  private var tabBarUnsafeHeight: CGFloat { tabBarViewModel.tabBarHeight + (UIApplication.shared.rootWindow?.safeAreaInsets.bottom ?? 0) }

  @ObserveInjection private var inject

  init(selectedIndex: Binding<Root.Tab>, screen1: T1, screen2: T2, screen3: T3) {
    _selectedIndex = selectedIndex
    self.screen1 = screen1
    self.screen2 = screen2
    self.screen3 = screen3
  }

  var body: some View {
    WithPerceptionTracking {
      ZStack(alignment: .bottom) {
        FluidGradient(
          blobs: [Color(hexString: "#000040"), Color(hexString: "#000030"), Color(hexString: "#000020")],
          highlights: [Color(hexString: "#1D004D"), Color(hexString: "#300055"), Color(hexString: "#100020")],
          speed: 0.2,
          blur: 0.75
        )
        .background(Color.DS.Background.primary)
        .ignoresSafeArea()

        ZStack(alignment: .top) {
          screen1
            .opacity(selectedIndex == .list ? 1 : 0)
            .frame(width: screenWidth)
            .offset(x: selectedIndex == .list ? 0 : -screenWidth, y: 0)

          screen2
            .opacity(selectedIndex == .record ? 1 : 0)
            .frame(width: screenWidth)
            .padding(.bottom, tabBarViewModel.tabBarHeight)

          screen3
            .opacity(selectedIndex == .settings ? 1 : 0)
            .frame(width: screenWidth)
            .offset(x: selectedIndex == .settings ? 0 : screenWidth, y: 0)
        }

        VariableBlurView(maxBlurRadius: 10)
          .rotationEffect(.degrees(180), anchor: .center)
          .allowsHitTesting(false)
          .frame(height: tabBarUnsafeHeight)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .opacity(tabBarViewModel.isVisible ? 1 : 0)
          .ignoresSafeArea()

        AnimatedTabBar(selectedIndex: $selectedIndex)
          .readSize { tabBarViewModel.tabBarHeight = $0.height }
          .offset(x: 0, y: tabBarViewModel.isVisible ? 0 : tabBarUnsafeHeight)
      }
      .animation(.showHide(), value: selectedIndex)
    }
    .readSize { screenWidth = $0.width }
    .enableInjection()
  }
}

// MARK: - TabBarContentInsetModifier

struct TabBarContentInsetModifier: ViewModifier {
  @Environment(TabBarViewModel.self) var tabBarViewModel: TabBarViewModel

  func body(content: Content) -> some View {
    WithPerceptionTracking {
      content.frame(height: tabBarViewModel.isVisible ? tabBarViewModel.tabBarHeight : 0)
    }
  }
}

extension View {
  func applyTabBarContentInset() -> some View {
    safeAreaInset(edge: .bottom) {
      Color.clear.modifier(TabBarContentInsetModifier())
    }
  }
}
