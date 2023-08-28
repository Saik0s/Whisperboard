import SwiftUI
import UIKit
@testable import WhisperBoardKit
import XCTest

@MainActor
final class TestHostingController<Content: View>: UIHostingController<Content> {
  override func viewDidLoad() {
    super.viewDidLoad()

    view.window?.overrideUserInterfaceStyle = .dark
    view.overrideUserInterfaceStyle = .dark

    configureDesignSystem()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    view.frame = view.window?.frame ?? UIScreen.main.bounds
  }
}
