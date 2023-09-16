#if os(iOS) || os(tvOS) || os(watchOS)
  import UIKit

  extension UIViewController {
    var topViewController: UIViewController {
      if let presentedViewController {
        return presentedViewController.topViewController
      }

      if let navigationController = self as? UINavigationController {
        return navigationController.visibleViewController?.topViewController ?? self
      }

      if let tabBarController = self as? UITabBarController {
        return tabBarController.selectedViewController?.topViewController ?? self
      }

      return self
    }
  }
#endif
