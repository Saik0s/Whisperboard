import AppDevUtils
import ComposableArchitecture
import SwiftUI

struct RecordingCardView: View {
  struct ViewState: Equatable {
    var title: String
    var dateString: String
    var currentTimeString: String
    var mode: RecordingCard.State.Mode
    var fileName: String
  }

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
    VStack(spacing: .grid(1)) {
      VStack(spacing: .grid(1)) {
        HStack(spacing: .grid(3)) {
          PlayButton(isPlaying: viewStore.mode.isPlaying) {
            viewStore.send(.playButtonTapped)
          }

          VStack(alignment: .leading, spacing: 0) {
            Text(viewStore.title)
              .font(.DS.bodyM)
              .foregroundColor(Color.DS.Text.base)
            Text(viewStore.dateString)
              .font(.DS.date)
              .foregroundColor(Color.DS.Text.subdued)
          }

          Text(viewStore.currentTimeString)
            .font(.DS.date)
            .foregroundColor(
              viewStore.mode.isPlaying
                ? Color.DS.Text.base
                : Color.DS.Text.subdued
            )
        }

        WaveformProgressView(
          audioURL: viewStore.fileName,
          progress: viewStore.mode.progress ?? 0,
          isPlaying: viewStore.mode.isPlaying
        )
      }
    }
      .padding(.grid(4))
      .cardStyle(isPrimary: viewStore.mode.isPlaying)
      .animation(.easeIn(duration: 0.3), value: viewStore.mode.isPlaying)
  }
}

// MARK: - PlayButton

struct PlayButton: View {
  var isPlaying: Bool
  var action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      Image(systemName: isPlaying ? "pause.circle" : "play.circle")
        .resizable()
        .aspectRatio(1, contentMode: .fit)
        .foregroundColor(.white)
        .animation(.easeInOut(duration: 0.15), value: isPlaying)
    }
      .aspectRatio(1, contentMode: .fit)
      .frame(width: 35, height: 35)
  }
}
