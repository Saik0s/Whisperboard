#if canImport(UIKit)
  import SwiftUI
  import UIKit

  struct UIViewRepresenting<View: UIView>: UIViewRepresentable {
    let view: View
    let updateUIView: (View, Context) -> Void

    init(view: View, updateUIView: @escaping (View, Context) -> Void) {
      self.view = view
      self.updateUIView = updateUIView
    }

    func makeUIView(context _: Context) -> View {
      view
    }

    func updateUIView(_ uiView: View, context: Context) {
      updateUIView(uiView, context)
    }
  }
#endif
