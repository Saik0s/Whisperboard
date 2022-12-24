//
// Created by Igor Tarasenko on 24/12/2022.
//

import SwiftUI

struct ActivityIndicator: UIViewRepresentable {

  typealias UIView = UIActivityIndicatorView
  var isAnimating: Bool = true
  fileprivate var configuration = { (indicator: UIView) in }

  func makeUIView(context: UIViewRepresentableContext<Self>) -> UIView { UIView() }
  func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<Self>) {
    isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    configuration(uiView)
  }
}

