import AppDevUtils
import SwiftUI

extension View {
  func onBecomeVisible(perform action: @escaping () -> Void) -> some View {
    onAppear(perform: action)
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        action()
      }
  }
}
