import SwiftUI
import UIKit
import AppDevUtils

struct CopyButton: View {
  var text: String

  var body: some View {
    Button {
      UIPasteboard.general.string = text
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } label: {
      Image(systemName: "doc.on.clipboard")
        .foregroundColor(Color.DS.Background.accent)
        .padding(.grid(1))
    }
  }
}
