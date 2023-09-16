#if os(iOS) || os(tvOS) || os(watchOS)
  import UIKit

  extension UIApplication {
    var keyWindowInConnectedScenes: UIWindow? {
      UIApplication.shared.connectedScenes
        .filter { $0.activationState == .foregroundActive }
        .compactMap { $0 as? UIWindowScene }
        .first?.windows
        .first { $0.isKeyWindow }
    }

    var rootViewController: UIViewController? {
      keyWindowInConnectedScenes?.rootViewController
    }

    var topViewController: UIViewController? {
      rootViewController?.topViewController
    }
  }
#endif
