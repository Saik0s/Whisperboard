import Popovers
import SwiftUI
import SwiftUIIntrospect
import VariableBlurView

extension Color {
  static var darkBlue: Color {
    Color(.sRGB, red: 70 / 255, green: 70 / 255, blue: 175 / 255, opacity: 1)
  }
}

// MARK: - CustomTabBarView

struct CustomTabBarView<T1: View, T2: View, T3: View>: View {
  @Binding var selectedIndex: Int
  var screen1: T1
  var screen2: T2
  var screen3: T3

  @Namespace private var animation

  var body: some View {
    VStack {
      ZStack {
        if selectedIndex == 0 {
          screen1
            .transition(.move(edge: .leading))
        } else if selectedIndex == 1 {
          screen2
//            .transition(.scale(scale: 0.5).combined(with: .opacity))
        } else if selectedIndex == 2 {
          screen3
            .transition(.move(edge: .trailing))
        }
      }.frame(maxHeight: .infinity, alignment: .top)

      AnimatedTabBar(selectedIndex: $selectedIndex, animation: animation)
    }
    .background(RootBackgroundView())
  }
}
