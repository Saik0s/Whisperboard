//
// UIApplication+window.swift
// GetLost
//

import UIKit

public extension UIApplication {
  var rootWindow: UIWindow? {
    connectedScenes
      .filter { $0.activationState == .foregroundActive }
      .compactMap { $0 as? UIWindowScene }
      .first?.windows
      .filter(\.isKeyWindow).first
  }
}
