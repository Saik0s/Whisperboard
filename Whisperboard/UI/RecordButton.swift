//
// Created by Igor Tarasenko on 08/01/2023.
//

import SwiftUI
import UIKit

struct RecordButton: View {
  let permission: Whispers.State.RecorderPermission
  let action: () -> Void
  let settingsAction: () -> Void

  var body: some View {
    ZStack {
      Button(action: self.action) {
        Circle()
          .fill(ColorPalette.orangeRed)
          .overlay {
            Image(systemName: "mic")
              .resizable()
              .scaledToFit()
              .frame(width: 30, height: 30)
              .foregroundColor(ColorPalette.darkness)
          }
      }
        .frame(width: 70, height: 70)
        .frame(maxWidth: .infinity)
        .padding(.grid(3))
        .opacity(self.permission == .denied ? 0.1 : 1)

      if self.permission == .denied {
        VStack(spacing: 10) {
          Text("Recording requires microphone access.")
            .multilineTextAlignment(.center)
          Button("Open Settings", action: self.settingsAction)
        }
          .frame(maxWidth: .infinity, maxHeight: 74)
      }
    }
  }
}
