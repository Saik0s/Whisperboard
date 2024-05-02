import ComposableArchitecture
import SwiftUI

// MARK: - PlayerControls

@Reducer
struct PlayerControls {
  @ObservableState
  struct State: Equatable {
    enum Mode: Equatable {
      case idle
      case playing(progress: Double)
      case paused(progress: Double)
    }

    @Shared var recording: RecordingInfo
    var mode = Mode.idle
    var waveform: WaveformProgress.State

    var isPlaying: Bool {
      switch mode {
      case .paused, .playing: true
      default: false
      }
    }

    var progress: Double? {
      switch mode {
      case let .paused(progress), let .playing(progress): progress
      default: nil
      }
    }

    var dateString: String {
      recording.date.formatted(date: .abbreviated, time: .shortened)
    }

    var currentTimeString: String {
      let currentTime = progress.map { $0 * recording.duration } ?? recording.duration
      return dateComponentsFormatter.string(from: currentTime) ?? ""
    }

    init(recording: Shared<RecordingInfo>) {
      _recording = recording
      waveform = .init(audioFileURL: recording.wrappedValue.fileURL, waveformImageURL: recording.wrappedValue.waveformImageURL)
    }
  }

  enum Action: ViewAction, Equatable {
    case view(View)

    @CasePathable
    enum View: BindableAction, Sendable, Equatable {
      case binding(BindingAction<State>)
      case waveform(WaveformProgress.Action)
      case playButtonTapped
      case playbackUpdated(PlaybackState)
    }
  }

  @Dependency(\.audioPlayer) var audioPlayer: AudioPlayerClient
  @Dependency(StorageClient.self) var storage: StorageClient

  private struct PlayID: Hashable {}

  var body: some Reducer<State, Action> {
    Scope(state: \.self, action: \.view) {
      viewBody
    }
  }

  @ReducerBuilder<State, Action.View> var viewBody: some Reducer<State, Action.View> {
    BindingReducer()

    Scope(state: \.waveform, action: \.waveform) {
      WaveformProgress()
    }

    Reduce<State, Action.View> { state, action in
      switch action {
      case .binding:
        return .none

//      case let .waveform(.didTouchAtHorizontalLocation(progress)):
//        guard state.mode.isPlaying else { return .none }
//        return .run { _ in
//          await audioPlayer.seekProgress(progress)
//        }

      case .waveform:
        return .none

      case .playButtonTapped:
        return .none
        //        switch state.mode {
//        case .idle:
//          state.mode = .playing(progress: 0)
//          return .run { [url = state.recording.fileURL] send in
//            for await playback in audioPlayer.play(url) {
//              await send(.playbackUpdated(playback))
//            }
//          }
//          .cancellable(id: PlayID(), cancelInFlight: true)
//
//        case let .playing(progress):
//          return .run { _ in
//            await audioPlayer.pause()
//          }
//
//        case let .paused(progress):
//          return .run { _ in
//            await audioPlayer.resume()
//          }
//        }

      case let .playbackUpdated(.playing(position)):
        state.mode = .playing(progress: position.progress)
        return .none

      case let .playbackUpdated(.pause(position)):
        state.mode = .paused(progress: position.progress)
        return .none

      case .playbackUpdated(.stop):
        state.mode = .idle
        return .none

      case let .playbackUpdated(.error(error)):
        let message = "Failed to play audio\n\(error?.localizedDescription ?? "Unknown error")"
        logs.error("\(message)")
        return .none

      case let .playbackUpdated(.finish(isSuccessful)):
        state.mode = .idle
        if !isSuccessful {
          logs.error("Failed to play audio")
        }
        return .cancel(id: PlayID())
      }
    }
  }
}

// MARK: - PlayerControlsView

@ViewAction(for: PlayerControls.self)
struct PlayerControlsView: View {
  @Perception.Bindable var store: StoreOf<PlayerControls>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(2)) {
        HStack(spacing: .grid(2)) {
          PlayButton(isPlaying: store.isPlaying) {
            send(.playButtonTapped, animation: .easeIn(duration: 0.3))
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
              store.isPlaying
                ? Color.DS.Text.accent
                : Color.DS.Text.base
            )
            .textStyle(.caption)
            .monospaced()
        }
        .padding([.horizontal, .top], .grid(2))

        if store.isPlaying {
          WaveformProgressView(store: store.scope(state: \.waveform, action: \.view.waveform))
            .transition(.scale.combined(with: .opacity))
            .padding(.horizontal, .grid(2))
        }
      }
      .animation(.interpolatingSpring(mass: 1, stiffness: 200, damping: 20), value: store.mode)
    }
  }
}
