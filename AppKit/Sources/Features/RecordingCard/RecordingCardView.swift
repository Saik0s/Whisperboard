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
      .cardButtonStyle()
    }
  }

  var cardView: some View {
    VStack(spacing: .grid(2)) {
      HStack(spacing: .grid(2)) {
        PlayButton(isPlaying: store.mode.isPlaying) {
          store.send(.playButtonTapped, animation: .easeIn(duration: 0.3))
        }

        VStack(alignment: .leading, spacing: .grid(1)) {
          if store.recording.title.isEmpty {
            Text("Untitled")
              .textStyle(.bodyBold)
              .opacity(0.5)
          } else {
            Text(store.recording.title)
              .textStyle(.bodyBold)
              .lineLimit(1)
          }

          Text(store.dateString)
            .textStyle(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(store.currentTimeString)
          .foregroundColor(
            store.mode.isPlaying
              ? Color.DS.Text.accent
              : Color.DS.Text.base
          )
          .textStyle(.caption)
          .monospaced()
      }
      .padding([.horizontal, .top], .grid(2))

      if store.mode.isPlaying {
        WaveformProgressView(
          store: store.scope(
            state: \.waveform,
            action: \.waveform
          )
        )
        .transition(.scale.combined(with: .opacity))
        .padding(.horizontal, .grid(2))
      }

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

                    Text(store.recording.lastTranscription?.status.message ?? "")
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
                Text(store.recording.lastTranscription?.status.message ?? "")
                  .textStyle(.body)

                HStack {
                  Button("Resume") {
                    store.send(.resumeTapped)
                  }.tertiaryButtonStyle()

                  Button("Start Over") {
                    store.send(.transcribeTapped)
                  }.tertiaryButtonStyle()
                }
              }
              .padding(.grid(2))
            } else if !store.recording.isTranscribed {
              VStack(spacing: .grid(1)) {
                if let error = store.recording.lastTranscriptionErrorMessage {
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
    .cardStyle(isPrimary: store.mode.isPlaying)
    .offset(y: showItem ? 0 : 200)
    .opacity(showItem ? 1 : 0)
    .animation(
      .spring(response: 0.6, dampingFraction: 0.75)
        .delay(Double(store.index) * 0.15),
      value: showItem
    )
    .alert($store.scope(state: \.alert, action: \.alert))
    .onAppear { showItem = true }
    .enableInjection()
  }
}
