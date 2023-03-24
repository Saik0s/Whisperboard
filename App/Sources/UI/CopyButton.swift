import AppDevUtils
import SwiftUI
import UIKit

struct CopyButton<Label: View>: View {
  var text: String
  var label: Label

  init(_ text: String, @ViewBuilder label: () -> Label) {
    self.text = text
    self.label = label()
  }

  var body: some View {
    Button {
      UIPasteboard.general.string = text
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } label: {
      label
    }
  }
}
