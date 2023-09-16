
import SwiftUI
import UIKit

struct RecordButton: View {
  let permission: RecordingControls.State.RecorderPermission
  let action: () -> Void
  let settingsAction: () -> Void

  @State private var didAppear = false

  var body: some View {
    ZStack {
      if didAppear {
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
        .transition(.offset(y: 300))
      }

      if permission == .denied {
        VStack(spacing: 10) {
          Text("Recording requires microphone access.")
            .multilineTextAlignment(.center)
          Button("Open Settings", action: settingsAction)
        }
        .frame(maxWidth: .infinity, maxHeight: 74)
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
        didAppear = true
      }
    }
    .onWillDisappear { didAppear = false }
    .onDisappear { didAppear = false }
  }
}
