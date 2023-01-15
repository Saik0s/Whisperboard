//
// CopyButton.swift
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
        .foregroundColor(Color.Palette.secondary)
        .padding(.grid(1))
    }
  }
}
