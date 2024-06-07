import Common
import Inject
import SwiftUI

struct RemoteTranscriptionImage: View {
  @State private var animating = false

  private let featureDescription = "Transcribe your recordings in the cloud super fast using the most capable"
  private let modelName = "Large-v2 Whisper model"

  var body: some View {
    VStack(spacing: 0) {
      WhisperBoardKitAsset.remoteTranscription.swiftUIImage
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: 70)
        .padding(.grid(2))
        .background(
          WhisperBoardKitAsset.remoteTranscription.swiftUIImage
            .resizable()
            .blur(radius: animating ? 30 : 20)
            .padding(.grid(2))
            .opacity(animating ? 1.0 : 0.3)
            .animation(Animation.interpolatingSpring(stiffness: 3, damping: 0.3).repeatForever(autoreverses: false), value: animating)
        )
        .onAppear { animating = true }

      VStack(spacing: 0) {
        Text(featureDescription)
          .textStyle(.headline)
        Text(modelName).shadow(color: .black, radius: 1, y: 1)
          .background(Text(modelName).blur(radius: 7))
          .foregroundStyle(
            LinearGradient(
              colors: [.DS.Text.accent, .DS.Background.accentAlt],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .textStyle(.headline)
      }
      .multilineTextAlignment(.center)
      .padding([.leading, .bottom, .trailing], .grid(2))
    }
    .frame(maxWidth: .infinity)
  }
}
