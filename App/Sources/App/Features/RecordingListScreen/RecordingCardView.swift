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
          if viewStore.recordingEnvelop.title.isEmpty {
            Text("Untitled")
              .font(.DS.headlineS)
              .foregroundColor(.DS.Text.subdued)
              .opacity(0.5)
          } else {
            Text(viewStore.recordingEnvelop.title)
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

      if viewStore.recordingEnvelop.isTranscribed && !viewStore.isTranscribing {
        VStack(alignment: .leading, spacing: .grid(2)) {
          Text(viewStore.transcription)
            .font(.DS.bodyS)
            .foregroundColor(.DS.Text.base)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack(spacing: .grid(2)) {
            CopyButton(viewStore.transcription) {
              Image(systemName: "doc.on.clipboard")
                .font(.DS.bodyS)
                .padding(.grid(2))
                .background {
                  Circle()
                    .fill(Color.DS.Background.accent.opacity(0.2))
                }
            }

            ShareButton(viewStore.transcription) {
              Image(systemName: "paperplane")
                .font(.DS.bodyS)
                .padding(.grid(2))
                .background {
                  Circle()
                    .fill(Color.DS.Background.accent.opacity(0.2))
                }
            }
          }.iconButtonStyle()
        }
      } else if viewStore.isTranscribing {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))
          .scaleEffect(1.5)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, .grid(2))
        // TODO: Implement cancel transcription https://github.com/ggerganov/whisper.cpp/blob/master/examples/main/main.cpp#L793
        // .overlay(alignment: .trailing) {
        //   Button("Cancel") {
        //     viewStore.send(.cancelTranscriptionTapped)
        //   }
        //   .tertiaryButtonStyle()
        //   .padding(.grid(4))
        //   .transition(.move(edge: .trailing))
        // }
      } else {
        Button("Transcribe") {
          viewStore.send(.transcribeTapped)
        }.tertiaryButtonStyle()
      }
    }
    .animation(.easeInOut(duration: 0.3), value: [viewStore.isTranscribing, viewStore.recordingEnvelop.isTranscribed])
    .multilineTextAlignment(.leading)
    .padding(.grid(4))
    .cardStyle(isPrimary: viewStore.mode.isPlaying)
    .alert(store.scope(state: \.alert), dismiss: .binding(.set(\.$alert, nil)))
    .animation(.easeIn(duration: 0.3), value: viewStore.mode.isPlaying)
    .task { await viewStore.send(.task).finish() }
    .enableInjection()
  }
}

private extension RecordingCard.State {
  var dateString: String {
    recordingEnvelop.date.formatted(date: .abbreviated, time: .shortened)
  }

  var currentTimeString: String {
    let currentTime = mode.progress.map { $0 * recordingEnvelop.duration } ?? recordingEnvelop.duration
    return dateComponentsFormatter.string(from: currentTime) ?? ""
  }

  var transcription: String {
    recordingEnvelop.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
