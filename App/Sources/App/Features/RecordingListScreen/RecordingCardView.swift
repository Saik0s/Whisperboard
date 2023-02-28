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
        fileName: state.recordingInfo.fileName
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
      }
    }
    .multilineTextAlignment(.leading)
    .padding(.grid(4))
    .background(Color.DS.Background.tertiary.opacity(viewStore.mode.isPlaying ? 0.7 : 0))
    .background(Color.DS.Background.secondary)
    .cornerRadius(.grid(4))
    .shadow(color: .DS.Background.accentAlt.darken().opacity(0.25),
            radius: viewStore.mode.isPlaying ? 12 : 0,
            y: viewStore.mode.isPlaying ? 8 : 0)
    .animation(.easeIn(duration: 0.3), value: viewStore.mode.isPlaying)
    .enableInjection()
  }
}
