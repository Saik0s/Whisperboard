//
// Created by Igor Tarasenko on 24/12/2022.
//

import SwiftUI

struct MyButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .padding()
      .background(Color(UIColor.systemGray3))
      .foregroundColor(Color(UIColor.label))
      .cornerRadius(5)
      .shadow(color: Color(UIColor.systemGray6), radius: 0.5, x: 0, y: 1)
      .overlay {
        ZStack {
          if configuration.isPressed {
            Color.black.opacity(0.5)
          }
        }
      }
  }
}
