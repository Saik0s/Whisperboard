//
// ShareButton.swift
//

import SwiftUI
import UIKit

struct ShareButton: View {
  var text: String

  var body: some View {
    Button {
      let text = text
      let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)

      UIApplication.shared.topViewController?.present(activityController, animated: true, completion: nil)
    } label: {
      Image(systemName: "paperplane")
        .foregroundColor(Color.Palette.secondary)
        .padding(.grid(1))
    }
  }
}
