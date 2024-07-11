import Common
import ComposableArchitecture
import SwiftUI

// MARK: - RecordButton

struct RecordButton: View {
  let permission: RecordingControls.State.RecorderPermission
  let action: () -> Void
  let settingsAction: () -> Void

  var body: some View {
    WithPerceptionTracking {
      ZStack {
        if permission != .denied {
          Button(action: action) {
            Circle()
              .fill(RadialGradient.accent)
              .overlay(
                Image(systemName: "mic")
                  .textStyle(.navigationTitle)
              )
          }
          .recordButtonStyle()
          .frame(width: 70, height: 70)
          .opacity(permission == .denied ? 0.1 : 1)
          .disabled(permission == .denied)
          .zIndex(1)
        }

        if permission == .denied {
          VStack(spacing: 10) {
            Text("Recording requires microphone access.")
              .multilineTextAlignment(.center)
            Button("Open Settings", action: settingsAction)
          }
          .frame(maxWidth: .infinity, maxHeight: 74)
          .zIndex(2)
        }
      }
    }
  }
}
