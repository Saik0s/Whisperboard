import AppDevUtils
import SwiftUI
import UIKit

struct RecordButton: View {
  let permission: RecordScreen.State.RecorderPermission
  let action: () -> Void
  let settingsAction: () -> Void

  var body: some View {
    ZStack {
      Button(action: action) {
        Circle()
          .fill(RadialGradient.accent)
          .overlay(Image(systemName: "mic")
                     .font(.DS.titleL)
                     .foregroundColor(.DS.Text.base))
      }
        .recordButtonStyle()
      .frame(width: 70, height: 70)
      .frame(maxWidth: .infinity)
      .padding(.grid(3))
      .opacity(permission == .denied ? 0.1 : 1)

      if permission == .denied {
        VStack(spacing: 10) {
          Text("Recording requires microphone access.")
            .multilineTextAlignment(.center)
          Button("Open Settings", action: settingsAction)
        }
        .frame(maxWidth: .infinity, maxHeight: 74)
      }
    }
  }
}
