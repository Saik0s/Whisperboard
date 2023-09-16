#if canImport(UIKit)
  import SwiftUI
  import UIKit

  // MARK: - WillDisappearHandler

  struct WillDisappearHandler: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController

    // MARK: Internal

    class Coordinator: UIViewController {
      // MARK: Lifecycle

      init(onWillDisappear: @escaping () -> Void) {
        self.onWillDisappear = onWillDisappear
        super.init(nibName: nil, bundle: nil)
      }

      @available(*, unavailable)
      required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
      }

      override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onWillDisappear()
      }

      // MARK: Internal

      let onWillDisappear: () -> Void
    }

    let onWillDisappear: () -> Void

    func makeCoordinator() -> WillDisappearHandler.Coordinator {
      Coordinator(onWillDisappear: onWillDisappear)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<WillDisappearHandler>) -> UIViewController {
      context.coordinator
    }

    func updateUIViewController(_: UIViewController, context _: UIViewControllerRepresentableContext<WillDisappearHandler>) {}
  }

  // MARK: - WillDisappearModifier

  struct WillDisappearModifier: ViewModifier {
    let callback: () -> Void

    func body(content: Content) -> some View {
      content
        .background(WillDisappearHandler(onWillDisappear: callback))
    }
  }

  extension View {
    func onWillDisappear(_ perform: @escaping () -> Void) -> some View {
      modifier(WillDisappearModifier(callback: perform))
    }
  }
#endif
