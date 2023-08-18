import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingCardView

struct RecordingCardView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordingCard>

  @ObservedObject var viewStore: ViewStoreOf<RecordingCard>

  init(store: StoreOf<RecordingCard>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  var body: some View {
    VStack(spacing: .grid(4)) {
      HStack(spacing: .grid(4)) {
        PlayButton(isPlaying: viewStore.mode.isPlaying) {
          viewStore.send(.playButtonTapped, animation: .easeIn(duration: 0.3))
        }

        VStack(alignment: .leading, spacing: .grid(1)) {
          if viewStore.recording.title.isEmpty {
            Text("Untitled")
              .font(.DS.headlineS)
              .foregroundColor(.DS.Text.subdued)
              .opacity(0.5)
          } else {
            Text(viewStore.recording.title)
              .font(.DS.headlineS)
              .foregroundColor(.DS.Text.base)
          }

          Text(viewStore.dateString)
            .font(.DS.captionM)
            .foregroundColor(.DS.Text.subdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(viewStore.currentTimeString)
          .font(.DS.date)
          .foregroundColor(
            viewStore.mode.isPlaying
              ? Color.DS.Text.accent
              : Color.DS.Text.base
          )
      }

      if viewStore.mode.isPlaying {
        WaveformProgressView(
          store: store.scope(
            state: { $0.waveform },
            action: { .waveform($0) }
          )
        )
        .transition(.scale.combined(with: .opacity))
      }

      ZStack(alignment: .top) {
        VStack(alignment: .leading, spacing: .grid(2)) {
          Text(viewStore.transcription)
            .font(.DS.bodyS)
            .foregroundColor(.DS.Text.base)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)

          if viewStore.recording.isTranscribed && !viewStore.isTranscribing {
            HStack(spacing: .grid(2)) {
              CopyButton(viewStore.transcription) {
                Image(systemName: "doc.on.clipboard")
              }

              ShareLink(item: viewStore.transcription) {
                Image(systemName: "paperplane")
              }
            }.iconButtonStyle()
          }
        }

        if viewStore.isTranscribing {
          Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(0.8)
            .blur(radius: 12)

          VStack(spacing: .grid(2)) {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))
              .scaleEffect(1.5)

            Text(viewStore.recording.lastTranscription?.status.message ?? "")
              .font(.DS.bodyS)
              .foregroundColor(.DS.Text.accent)

            Button("Cancel") {
              viewStore.send(.cancelTranscriptionTapped)
            }.tertiaryButtonStyle()
          }
          .padding(.grid(2))
        } else if let queuePosition = viewStore.queuePosition, let queueTotal = viewStore.queueTotal {
          VStack(spacing: .grid(2)) {
            Text("In queue: \(queuePosition) of \(queueTotal)")
              .font(.DS.bodyS)
              .foregroundColor(.DS.Text.accent)

            Button("Cancel") {
              viewStore.send(.cancelTranscriptionTapped)
            }.tertiaryButtonStyle()
          }
        } else if !viewStore.recording.isTranscribed {
          Button("Transcribe") {
            viewStore.send(.transcribeTapped)
          }.tertiaryButtonStyle()
        }
      }
    }
    .animation(.easeInOut(duration: 0.3), value: viewStore.recording)
    .multilineTextAlignment(.leading)
    .padding(.grid(4))
    .cardStyle(isPrimary: viewStore.mode.isPlaying)
    .alert(store.scope(state: \.alert, action: { $0 }), dismiss: .binding(.set(\.$alert, nil)))
    .enableInjection()
  }
}
