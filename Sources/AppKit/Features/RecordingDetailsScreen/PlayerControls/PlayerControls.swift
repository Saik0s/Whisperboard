import Common
import ComposableArchitecture
import SwiftUI

// MARK: - PlayerControls

@Reducer
struct PlayerControls {
  @ObservableState
  struct State: Equatable {
    @CasePathable
    enum Mode: Equatable {
      case idle
      case playing(progress: Double)
      case paused(progress: Double)
    }

    var mode = Mode.idle
    var waveform: WaveformProgress.State

    var isPlaying: Bool {
      mode.is(\.playing)
    }

    var progress: Double? {
      switch mode {
      case let .paused(progress), let .playing(progress): progress
      default: nil
      }
    }

    var title: String
    var dateString: String
    var duration: TimeInterval
    var audioFileURL: URL { waveform.audioFileURL }

    var currentTimeString: String {
      let currentTime = progress.map { $0 * duration } ?? duration
      return dateComponentsFormatter.string(from: currentTime.isNaN ? 0 : currentTime) ?? ""
    }

    init(recording: RecordingInfo) {
      title = recording.title
      dateString = recording.date.formatted(date: .abbreviated, time: .shortened)
      duration = recording.duration
      waveform = .init(
        audioFileURL: recording.fileURL,
        waveformImageURL: recording.waveformImageURL,
        duration: recording.duration
      )
    }
  }

  enum Action: BindableAction, Equatable {
      case binding(BindingAction<State>)
      case waveform(WaveformProgress.Action)
      case playButtonTapped
      case playbackUpdated(PlaybackState)
  }

  @Dependency(\.audioPlayer) var audioPlayer: AudioPlayerClient
  @Dependency(StorageClient.self) var storage: StorageClient

  private struct PlayID: Hashable {}

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.waveform, action: \.waveform) {
      WaveformProgress()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .waveform(.binding(\.progress)):
        guard state.mode.is(\.playing) else { return .none }
        return .run { [progress = state.waveform.progress] _ in
          await audioPlayer.seekProgress(progress)
        }

      case .waveform:
        return .none

      case .playButtonTapped:
        switch state.mode {
        case .idle:
          state.mode = .playing(progress: 0)
          updateWaveform(state: &state)
          return .run { [url = state.audioFileURL] send in
            for await playback in audioPlayer.play(url) {
              await send(.playbackUpdated(playback))
            }

            await audioPlayer.stop()
          }
          .cancellable(id: PlayID(), cancelInFlight: true)

        case .playing:
          return .run { send in
            //            await audioPlayer.pause()
            await audioPlayer.stop()
          }

        case .paused:
          return .run { _ in
            await audioPlayer.resume()
          }
        }

      case let .playbackUpdated(.playing(position)):
        state.mode = .playing(progress: position.progress)
        updateWaveform(state: &state)
        return .none

      case let .playbackUpdated(.pause(position)):
        state.mode = .paused(progress: position.progress)
        updateWaveform(state: &state)
        return .none

      case .playbackUpdated(.stop):
        state.mode = .idle
        updateWaveform(state: &state)
        return .cancel(id: PlayID())

      case let .playbackUpdated(.error(error)):
        state.mode = .idle
        updateWaveform(state: &state)
        let message = "Failed to play audio \(error?.localizedDescription ?? "Unknown error")"
        logs.error("\(message)")
        return .cancel(id: PlayID())

      case let .playbackUpdated(.finish(isSuccessful)):
        state.mode = .idle
        updateWaveform(state: &state)
        if !isSuccessful {
          logs.error("Failed to play audio")
        }
        return .cancel(id: PlayID())
      }
    }
  }

  func updateWaveform(state: inout State) {
    guard !state.waveform.isSeeking else { return }
    switch state.mode {
    case .idle:
      state.waveform.progress = 0
      state.waveform.isPlaying = false

    case let .playing(progress):
      state.waveform.progress = progress
      state.waveform.isPlaying = true

    case let .paused(progress):
      state.waveform.progress = progress
      state.waveform.isPlaying = true
    }
  }
}

// MARK: - PlayerControlsView

struct PlayerControlsView: View {
  @Perception.Bindable var store: StoreOf<PlayerControls>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(2)) {
        HStack(spacing: .grid(2)) {
          PlayButton(isPlaying: store.isPlaying) {
            store.send(.playButtonTapped)
          }

          VStack(alignment: .leading, spacing: .grid(1)) {
            if store.title.isEmpty {
              Text("Untitled")
                .textStyle(.bodyBold)
                .opacity(0.5)
            } else {
              Text(store.title)
                .textStyle(.bodyBold)
                .lineLimit(1)
            }

            Text(store.dateString)
              .textStyle(.footnote)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          Text(store.currentTimeString)
            .foregroundColor(
              store.isPlaying
                ? Color.DS.Text.accent
                : Color.DS.Text.base
            )
            .textStyle(.caption)
            .monospaced()
        }
        .padding([.horizontal, .top], .grid(2))

        if store.isPlaying {
          WaveformProgressView(store: store.scope(state: \.waveform, action: \.waveform))
            .transition(.scale.combined(with: .opacity))
            .padding(.horizontal, .grid(2))
        }
      }
      .animation(.smooth, value: store.mode)
    }
  }
}
