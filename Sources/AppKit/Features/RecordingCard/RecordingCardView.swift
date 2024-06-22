import Common
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingCardView

@MainActor
struct RecordingCardView: View {
  @Perception.Bindable var store: StoreOf<RecordingCard>

  @State var showItem = false

  var body: some View {
    WithPerceptionTracking {
      NavigationLink(state: Root.Path.State.details(RecordingDetails.State(recordingCard: store.state))) {
        cardView
      }
    }
  }

  var cardView: some View {
    VStack(spacing: .grid(2)) {
      PlayerControlsView(store: store.scope(state: \.playerControls, action: \.playerControls))

      ZStack(alignment: .top) {
        VStack(alignment: .leading, spacing: .grid(2)) {
          Text(store.transcription)
            .textStyle(.body)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)

          if store.recording.isTranscribed {
            HStack(spacing: .grid(2)) {
              CopyButton(store.transcription) {
                Image(systemName: "doc.on.clipboard")
              }

              ShareLink(item: store.transcription) {
                Image(systemName: "paperplane")
              }
            }.iconButtonStyle()
          }
        }
        .padding([.horizontal, .bottom], .grid(2))

        if store.recording.isTranscribing || store.queueInfo != nil || !store.recording.isTranscribed {
          ZStack {
            Rectangle()
              .fill(.ultraThinMaterial)
              .continuousCornerRadius(.grid(2))

            TranscriptionControlsView(store: store)
          }
          .transition(.scale(scale: 0, anchor: .top).combined(with: .opacity).animation(.easeInOut(duration: 0.2)))
        }
      }
    }
    .multilineTextAlignment(.leading)
    .padding(.grid(2))
    .cardStyle(isPrimary: store.playerControls.isPlaying)
    .offset(y: showItem ? 0 : 200)
    .opacity(showItem ? 1 : 0)
    .onAppear {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
        showItem = true
      }
    }
  }
}

// MARK: - TranscriptionControlsView

struct TranscriptionControlsView: View {
  @Perception.Bindable var store: StoreOf<RecordingCard>

  var body: some View {
    WithPerceptionTracking {
      if store.recording.transcription?.status.isPaused == true {
        pausedTranscriptionView
      } else if store.recording.isTranscribing {
        transcribingView
      } else if let queueInfo = store.queueInfo, queueInfo.position > 0 {
        queueInfoView(queueInfo: queueInfo)
      } else if !store.recording.isTranscribed {
        notTranscribedView
      }
    }
  }

  private var pausedTranscriptionView: some View {
    VStack(spacing: .grid(1)) {
      Text(store.recording.transcription?.status.message ?? "")
        .textStyle(.body)

      Button("Start Over") {
        store.send(.transcribeButtonTapped)
      }.tertiaryButtonStyle()
    }
    .padding(.grid(2))
  }

  private var transcribingView: some View {
    VStack(spacing: .grid(2)) {
      HStack(spacing: .grid(2)) {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))

        Text(store.recording.transcription?.status.message ?? "")
          .textStyle(.subheadline)
      }

      Button("Cancel") {
        store.send(.cancelTranscriptionButtonTapped)
      }.tertiaryButtonStyle()
    }
    .padding(.grid(2))
  }

  private func queueInfoView(queueInfo: RecordingCard.QueueInfo) -> some View {
    VStack(spacing: .grid(2)) {
      Text("In queue: \(queueInfo.position) of \(queueInfo.total)")
        .textStyle(.body)

      Button("Cancel") {
        store.send(.cancelTranscriptionButtonTapped)
      }.tertiaryButtonStyle()
    }
    .padding(.grid(2))
  }

  private var notTranscribedView: some View {
    VStack(spacing: .grid(1)) {
      if let error = store.recording.transcription?.status.errorMessage {
        Text(error)
          .textStyle(.error)
      }

      Button("Transcribe") {
        store.send(.transcribeButtonTapped)
      }
      .tertiaryButtonStyle()
    }
    .padding(.grid(2))
  }
}
