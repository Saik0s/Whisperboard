import Common
import Injection
import SwiftUI

// MARK: - LiveTranscriptionSelector

struct LiveTranscriptionSelector: View {
  @Binding var selectedModel: Model.ID
  let availableModels: [Model]
  let isFeaturePurchased: Bool
  @State private var showInfoPopup = false

  var body: some View {
    ZStack {
      HStack(spacing: .grid(1)) {
        Text("Live Transcription")
          .font(.headline)

        ModelSelectorDropdown(selectedModel: $selectedModel, availableModels: availableModels, isEnabled: true)

        Button(action: { showInfoPopup = true }) {
          Image(systemName: "info.circle")
            .foregroundColor(.blue)
        }
        .padding(.leading, .grid(2))
      }

      if !isFeaturePurchased {
        HStack {
          Image(systemName: "lock.fill")
            .font(.title)
            .foregroundColor(.DS.code03)
            .shadow(color: .DS.Background.accent.opacity(0.3), radius: 4, x: 0, y: 0)

          Text("Unlock Live Transcription to access this premium feature!")
            .font(.subheadline)
            .foregroundColor(.DS.Text.subdued)
            .padding(.leading, .grid(1))
            .padding(.trailing, .grid(7))
        }
        .padding()
        .cardStyle()
        .overlay(alignment: .topTrailing) {
          Button(action: {}) {
            Image(systemName: "info.circle")
              .foregroundColor(.DS.Text.base)
              .font(.body)
              .padding(8)
          }
        }
      }
    }
    .sheet(isPresented: $showInfoPopup) {
      InfoPopupView()
    }
  }
}

// MARK: - InfoPopupView

struct InfoPopupView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Live Transcription")
        .font(.title)
        .fontWeight(.bold)

      Text(
        "Live Transcription allows you to convert speech to text in real-time. Choose from various models to optimize accuracy for your specific needs."
      )
      .font(.body)

      Text("Premium Feature:")
        .font(.headline)
        .padding(.top)

      Text("• Real-time speech-to-text conversion\n• Multiple language support\n• High accuracy with customizable models")
        .font(.body)

      Spacer()

      Button("Close") {
        // Dismiss the sheet
      }
      .frame(maxWidth: .infinity)
    }
    .padding()
  }
}

// MARK: - LiveTranscriptionSelector_Previews

/// Preview
struct LiveTranscriptionSelector_Previews: PreviewProvider {
  static var previews: some View {
    LiveTranscriptionSelector(
      selectedModel: .constant(Model.mockModels[0].id),
      availableModels: Model.mockModels,
      isFeaturePurchased: false
    )
  }
}
