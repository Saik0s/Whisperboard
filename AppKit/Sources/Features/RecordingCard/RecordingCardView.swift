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
      Button { store.send(.recordingSelected) } label: {
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

          if store.recording.isTranscribed && !store.isTranscribing {
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

        if store.isTranscribing || store.queuePosition != nil || !store.recording.isTranscribed {
          ZStack {
            Rectangle()
              .fill(.ultraThinMaterial)
              .continuousCornerRadius(.grid(2))

            if store.isTranscribing || store.queuePosition != nil {
              VStack(spacing: .grid(2)) {
                if store.isTranscribing {
                  HStack(spacing: .grid(2)) {
                    ProgressView()
                      .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))

                    Text(store.recording.transcription?.status.message ?? "")
                      .textStyle(.subheadline)
                  }
                } else if let queuePosition = store.queuePosition, let queueTotal = store.queueTotal {
                  Text("In queue: \(queuePosition) of \(queueTotal)")
                    .textStyle(.body)
                }

                Button("Cancel") {
                  store.send(.cancelTranscriptionTapped)
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
                    store.send(.transcribeTapped)
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
                  store.send(.transcribeTapped)
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
    .animation(.easeInOut(duration: 0.3), value: store.state)
    .multilineTextAlignment(.leading)
    .padding(.grid(2))
    .cardStyle(isPrimary: store.playerControls.isPlaying)
    .offset(y: showItem ? 0 : 200)
    .opacity(showItem ? 1 : 0)
//    .animation(
//      .spring(response: 0.3, dampingFraction: 0.75),
//        // .delay(Double(store.index) * 0.15),
//      value: showItem
//    )
    .alert($store.scope(state: \.alert, action: \.alert))
    .onAppear {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
        showItem = true
      }
    }
    .enableInjection()
  }
}
