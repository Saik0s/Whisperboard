//
// Created by Igor Tarasenko on 08/01/2023.
//

import SwiftUI
import UIKit

struct CopyButton: View {
  var text: String

  var body: some View {
    Button {
      UIPasteboard.general.string = text
    } label: {
      Image(systemName: "doc.on.clipboard")
        .foregroundColor(ColorPalette.orangeRed)
        .padding(.grid(1))
    }
  }
}
