import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingCardView

struct RecordingCardView: View {
  struct ViewState: Equatable {
    var title: String
    var dateString: String
    var currentTimeString: String
    var mode: RecordingCard.State.Mode
    var fileName: String
    var isTranscribed: Bool
    var isTranscribing: Bool
    var transcription: String
  }

  @ObserveInjection var inject

  let store: StoreOf<RecordingCard>
  @ObservedObject var viewStore: ViewStore<ViewState, RecordingCard.Action>

  init(store: StoreOf<RecordingCard>) {
    self.store = store
    viewStore = ViewStore(store.scope { state in
      let currentTime = state.mode.progress.map { $0 * state.recordingInfo.duration } ?? state.recordingInfo.duration

      return ViewState(
        title: state.recordingInfo.title,
        dateString: state.recordingInfo.date.formatted(date: .abbreviated, time: .shortened),
        currentTimeString: dateComponentsFormatter.string(from: currentTime) ?? "",
        mode: state.mode,
        fileName: state.recordingInfo.fileName,
        isTranscribed: state.recordingInfo.isTranscribed,
        isTranscribing: state.isTranscribing,
        transcription: state.recordingInfo.text.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    })
  }

  var body: some View {
    VStack(spacing: .grid(4)) {
      HStack(spacing: .grid(4)) {
        PlayButton(isPlaying: viewStore.mode.isPlaying) {
          viewStore.send(.playButtonTapped, animation: .easeIn(duration: 0.3))
        }

        VStack(alignment: .leading, spacing: .grid(1)) {
          if viewStore.title.isEmpty {
            Text("Untitled")
              .font(.DS.headlineS)
              .foregroundColor(.DS.Text.subdued)
              .opacity(0.5)
          } else {
            Text(viewStore.title)
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

      if viewStore.isTranscribed {
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
      } else {
        Button("Transcribe") { viewStore.send(.transcribeTapped) }
          .tertiaryButtonStyle()
      }
    }
    .animation(.easeInOut(duration: 0.3), value: [viewStore.isTranscribing, viewStore.isTranscribed])
    .multilineTextAlignment(.leading)
    .padding(.grid(4))
    .cardStyle(isPrimary: viewStore.mode.isPlaying)
    .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
    .animation(.easeIn(duration: 0.3), value: viewStore.mode.isPlaying)
    .enableInjection()
  }
}
