//
// Created by Igor Tarasenko on 08/01/2023.
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
        .foregroundColor(ColorPalette.orangeRed)
        .padding(.grid(1))
    }
  }
}

