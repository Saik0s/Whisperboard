import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingCardView

struct RecordingCardView: View {
  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<RecordingCard>

  @State var showItem = false

  var body: some View {
    WithPerceptionTracking {
      NavigationLink(state: Root.Path.State.details(RecordingDetails.State(recordingCard: store.state))) {
        cardView
      }.buttonStyle(PlainButtonStyle())
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

          if store.recording.isTranscribed && !store.recording.isTranscribing {
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

            if store.recording.isTranscribing || store.queueInfo != nil {
              VStack(spacing: .grid(2)) {
                if store.recording.isTranscribing {
                  HStack(spacing: .grid(2)) {
                    ProgressView()
                      .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))

                    Text(store.recording.transcription?.status.message ?? "")
                      .textStyle(.subheadline)
                  }
                } else if let queueInfo = store.queueInfo {
                  Text("In queue: \(queueInfo.position) of \(queueInfo.total)")
                    .textStyle(.body)
                }

                Button("Cancel") {
                  store.send(.cancelTranscriptionButtonTapped)
                }.tertiaryButtonStyle()
              }
              .padding(.grid(2))
            } else if store.recording.isPaused {
              VStack(spacing: .grid(1)) {
                Text(store.recording.transcription?.status.message ?? "")
                  .textStyle(.body)

                HStack {
                  Button("Resume") {
                    store.send(.didTapResumeTranscription)
                  }.tertiaryButtonStyle()

                  Button("Start Over") {
                    store.send(.transcribeButtonTapped)
                  }.tertiaryButtonStyle()
                }
              }
              .padding(.grid(2))
            } else if !store.recording.isTranscribed {
              VStack(spacing: .grid(1)) {
                if let error = store.recording.transcriptionErrorMessage {
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
          .transition(.scale(scale: 0, anchor: .top).combined(with: .opacity).animation(.easeInOut(duration: 0.2)))
        }
      }
    }
//    .animation(.easeInOut(duration: 0.3), value: store.state)
    .multilineTextAlignment(.leading)
    .padding(.grid(2))
    .cardStyle(isPrimary: store.playerControls.isPlaying)
    .offset(y: showItem ? 0 : 200)
    .opacity(showItem ? 1 : 0)
    .alert($store.scope(state: \.alert, action: \.alert))
    .onAppear {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
        showItem = true
      }
    }
    .enableInjection()
  }
}
