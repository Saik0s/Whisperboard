import FluidGradient
import Inject
import Popovers
import SwiftUI
import SwiftUIIntrospect
import VariableBlurView

// MARK: - TabBarViewModel

final class TabBarViewModel: ObservableObject {
  @Published var tabBarHeight: CGFloat = 44
  @Published var isVisible = false
}

// MARK: - TabBarContainerView

struct TabBarContainerView<T1: View, T2: View, T3: View>: View {
  @Binding var selectedIndex: Int
  var screen1: T1
  var screen2: T2
  var screen3: T3

  @StateObject private var tabBarViewModel = TabBarViewModel()
  @State private var screenWidth: CGFloat = UIScreen.main.bounds.width

  @Namespace private var animation

  @ObserveInjection private var inject

  var body: some View {
    ZStack {
//      RootBackgroundView()

      FluidGradient(
        blobs: [Color(hexString: "#000029"), Color(hexString: "#140029"), Color(hexString: "#000000")],
        highlights: [Color(hexString: "#00003D"), Color(hexString: "#000552"), Color(hexString: "#000552")],
        speed: 0.2,
        blur: 0.75
      )
      .background(Color.DS.Background.primary)
      .ignoresSafeArea()

      ZStack(alignment: .top) {
        screen1
          .opacity(selectedIndex == 0 ? 1 : 0)
          .frame(width: screenWidth)
          .offset(x: selectedIndex == 0 ? 0 : -screenWidth, y: 0)

        if selectedIndex == 1 {
          screen2
            .frame(width: screenWidth)
            .padding(.bottom, tabBarViewModel.tabBarHeight)
        }

        screen3
          .opacity(selectedIndex == 2 ? 1 : 0)
          .frame(width: screenWidth)
          .offset(x: selectedIndex == 2 ? 0 : screenWidth, y: 0)
      }
      .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedIndex)

      if tabBarViewModel.isVisible {
        AnimatedTabBar(selectedIndex: $selectedIndex, animation: animation)
          .frame(width: screenWidth)
          .readSize { tabBarViewModel.tabBarHeight = $0.height }
          .frame(maxHeight: .infinity, alignment: .bottom)
          .transition(.move(edge: .bottom))
      }
    }
    // .readSize { screenWidth = $0.width }
    .onAppear {
      withAnimation(.interpolatingSpring(stiffness: 100, damping: 10)) {
        tabBarViewModel.isVisible = true
      }
    }
    .environmentObject(tabBarViewModel)
    .enableInjection()
  }
}

// MARK: - TabBarContentInsetModifier

struct TabBarContentInsetModifier: ViewModifier {
  @EnvironmentObject var tabBarViewModel: TabBarViewModel

  func body(content: Content) -> some View {
    content
      .frame(height: tabBarViewModel.isVisible ? tabBarViewModel.tabBarHeight : 0)
  }
}

extension View {
  func applyTabBarContentInset() -> some View {
    safeAreaInset(edge: .bottom) {
      Color.clear.modifier(TabBarContentInsetModifier())
    }
  }
}
