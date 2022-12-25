import ComposableArchitecture
import SwiftUI
import DSWaveformImageViews
import DSWaveformImage

struct Whisper: ReducerProtocol {
  struct State: Equatable, Identifiable, Codable {
    var date: Date
    var duration: TimeInterval
    var mode = Mode.notPlaying
    var title = ""
    var fileName: String
    var text: String = ""
    var isTranscribed = false

    var id: String { fileName }

    enum Mode: Equatable, Codable {
      case notPlaying
      case playing(progress: Double)

      var isPlaying: Bool {
        if case .playing = self { return true }
        return false
      }

      var progress: Double? {
        if case let .playing(progress) = self { return progress }
        return nil
      }
    }
  }

  enum Action: Equatable {
    case audioPlayerClient(TaskResult<Bool>)
    case delete
    case playButtonTapped
    case timerUpdated(TimeInterval)
    case titleTextFieldChanged(String)
    case bodyTapped
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.continuousClock) var clock
  @Dependency(\.storage) var storage

  private enum PlayID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .audioPlayerClient:
      state.mode = .notPlaying
      return .cancel(id: PlayID.self)

    case .delete:
      return .cancel(id: PlayID.self)

    case .playButtonTapped:
      switch state.mode {
      case .notPlaying:
        state.mode = .playing(progress: 0)

        return .run { [fileName = state.fileName] send in
          let url = storage.fileURLWithName(fileName)
          async let playAudio: Void = send(
            .audioPlayerClient(TaskResult { try await self.audioPlayer.play(url) })
          )

          var start: TimeInterval = 0
          for await _ in self.clock.timer(interval: .milliseconds(500)) {
            start += 0.5
            await send(.timerUpdated(start))
          }

          await playAudio
        }
          .cancellable(id: PlayID.self, cancelInFlight: true)

      case .playing:
        state.mode = .notPlaying
        return .cancel(id: PlayID.self)
      }

    case let .timerUpdated(time):
      switch state.mode {
      case .notPlaying:
        break
      case .playing:
        state.mode = .playing(progress: time / state.duration)
      }
      return .none

    case let .titleTextFieldChanged(text):
      state.title = text
      return .none

    case .bodyTapped:
      return .none
    }
  }
}

extension ViewStore where ViewState == Whisper.State {
  var currentTime: TimeInterval {
    state.mode.progress.map { $0 * state.duration } ?? state.duration
  }
}

struct WhisperView: View {
  let store: StoreOf<Whisper>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        TextField(
          "Untitled, \(viewStore.date.formatted(date: .numeric, time: .shortened))",
          text: viewStore.binding(get: \.title, send: { .titleTextFieldChanged($0) })
        )
          .foregroundColor(ColorPalette.grayish)

        HStack(spacing: .grid(4)) {
          PlayButton(isPlaying: viewStore.mode.isPlaying) {
            viewStore.send(.playButtonTapped)
          }

          WaveformProgressView(
            audioURL: Storage.liveValue.fileURLWithName(viewStore.fileName),
            progress: viewStore.mode.progress ?? 0,
            isPlaying: viewStore.mode.isPlaying
          )
            .onTapGesture { viewStore.send(.bodyTapped) }

          dateComponentsFormatter.string(from: viewStore.currentTime).map {
            Text($0)
              .font(.footnote.monospacedDigit())
              .foregroundColor(viewStore.mode.isPlaying
                                 ? ColorPalette.white
                                 : ColorPalette.lightGray)
              .onTapGesture { viewStore.send(.bodyTapped) }
          }
        }
          .padding(.trailing, .grid(4))
          .padding(.grid(1))
          .background(viewStore.mode.isPlaying
                        ? ColorPalette.itemHighlightedBackground
                        : ColorPalette.itemBackground)
          .frame(height: 50)
          .cornerRadius(25, antialiased: true)
      }
        .background(ColorPalette.darkness.cornerRadius(25, corners: [.bottomLeft, .bottomRight]))
    }
  }
}

struct WaveformProgressView: View {
  var audioURL: URL
  var configuration = Waveform.Configuration(
    size: .zero,
    backgroundColor: .clear,
    style: .striped(.init(color: .white, width: 3, spacing: 3, lineCap: .round)),
    dampening: Waveform.Dampening(),
    position: .middle,
    scale: DSScreen.scale,
    verticalScalingFactor: 0.95,
    shouldAntialias: true
  )
  var progress = 0.0
  var isPlaying = false

  var notPlayedConfiguration: Waveform.Configuration {
    configuration
      .with(style: .striped(.init(color: UIColor(ColorPalette.grayish), width: 3, spacing: 3, lineCap: .round)))
  }

  var body: some View {
    ZStack(alignment: .leading) {
      WaveformView(audioURL: audioURL, configuration: notPlayedConfiguration)
      WaveformView(audioURL: audioURL, configuration: configuration)
        .mask(alignment: .leading) {
          GeometryReader { geometry in
            if isPlaying {
              Rectangle().frame(width: geometry.size.width * progress)
            } else {
              Rectangle()
            }
          }
        }
    }
      .animation(.linear(duration: 0.5), value: progress)
  }
}

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
  }
}