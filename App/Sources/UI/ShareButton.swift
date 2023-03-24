import AppDevUtils
import SwiftUI
import UIKit

struct ShareButton<Value, Label: View>: View {
  var value: Value
  var label: Label

  init(_ value: Value, @ViewBuilder label: () -> Label) {
    self.value = value
    self.label = label()
  }

  var body: some View {
    Button {
      let activityController = UIActivityViewController(activityItems: [value], applicationActivities: nil)

      UIApplication.shared.topViewController?.present(activityController, animated: true, completion: nil)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } label: {
      label
    }
  }
}
