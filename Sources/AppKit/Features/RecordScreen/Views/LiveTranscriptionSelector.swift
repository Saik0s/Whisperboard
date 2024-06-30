import Common
import Inject
import Pow
import SwiftUI
import Popovers

// MARK: - LiveTranscriptionSelector

struct LiveTranscriptionSelector: View {
  @Binding var selectedModel: Model.ID
  let availableModels: [Model]
  let isFeaturePurchased: Bool
  @State private var showInfoPopup = false
  @State var isPressed: Bool = false
  @State var shine: Bool = false

  @ObserveInjection private var injection

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
            .foregroundColor(Color(.systemYellow))
            .shadow(color: Color(.systemYellow).opacity(0.5), radius: 8, x: 0, y: 0)

          Text("Hey there! Wanna try Live Transcription? It's a cool feature you can unlock by upgrading.")
            .textStyle(.subheadline)
            .foregroundColor(.DS.Text.base)
            .padding(.leading, .grid(1))
            .padding(.trailing, .grid(7))
        }
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        ._onButtonGesture {
          isPressed = $0
        } perform: {
          
        }
        .overlay(alignment: .topTrailing) {
          Button(action: { showInfoPopup.toggle() }) {
            Image(systemName: "info.circle")
              .foregroundColor(.DS.Text.base)
              .font(.body)
              .padding(8)
          }
        }
        .conditionalEffect(.pushDown, condition: isPressed)
        .compositingGroup()
        .changeEffect(.shine.delay(1), value: shine, isEnabled: !shine)
        .onAppear { _ = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in withAnimation { shine.toggle() } } }
      }
    }
    .popover(
      present: $showInfoPopup,
      attributes: {
      //  $0.position = .relativeClosestAnchor(.top)
        $0.presentation = .init(animation: .bouncy, transition: .movingParts.swoosh.combined(with: .opacity))
        $0.dismissal = .init(
          animation: .bouncy,
          transition: .movingParts.swoosh.combined(with: .opacity),
          mode: [.dragDown, .dragUp]
        )
        $0.blocksBackgroundTouches = true
      }
    ) {
      InfoPopupView()
    } background: {
      Rectangle().fill(.ultraThinMaterial)
    }
    .enableInjection()
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
        "Live Transcription converts speech to text in real-time as you speak. It uses advanced AI models to process audio and generate accurate transcripts instantly."
      )
      .font(.body)

      Text("How to use:")
        .font(.headline)
        .padding(.top, 8)

      VStack(alignment: .leading, spacing: 8) {
        Text("1. Select a transcription model")
        Text("2. Start recording your audio")
        Text("3. Watch as text appears in real-time")
        Text("4. Edit or export your transcript when finished")
      }
      .font(.body)

      Text("Benefits:")
        .font(.headline)
        .padding(.top, 8)

      VStack(alignment: .leading, spacing: 8) {
        Text("• Instant feedback on your speech")
        Text("• Easily capture and review spoken content")
        Text("• Save time on manual transcription")
        Text("• Support for multiple languages")
      }
      .font(.body)
    }
    .padding(.grid(4))
    .cardStyle()
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
