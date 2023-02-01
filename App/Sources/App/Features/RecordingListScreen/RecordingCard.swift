import AppDevUtils
import ComposableArchitecture
import SwiftUI

// MARK: - RecordingCard

public struct RecordingCard: ReducerProtocol {
  public struct State: Equatable, Identifiable, Codable, Then {
    enum Mode: Equatable, Codable {
      case notPlaying
      case playing(progress: Double)
    }

    var recordingInfo: RecordingInfo
    var mode = Mode.notPlaying
    var isTranscribing = false
    var isExpanded = false

    public var id: String { recordingInfo.id }

    init(recordingInfo: RecordingInfo) {
      self.recordingInfo = recordingInfo
    }
  }

  public enum Action: Equatable {
    case audioPlayerClient(TaskResult<Bool>)
    case playButtonTapped
    case progressUpdated(Double)
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.continuousClock) var clock
  @Dependency(\.storage) var storage

  private enum PlayID {}

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .audioPlayerClient:
      state.mode = .notPlaying
      return .cancel(id: PlayID.self)

    case .playButtonTapped:
      switch state.mode {
      case .notPlaying:
        state.mode = .playing(progress: 0)

        return .run { [fileName = state.recordingInfo.fileName] send in
          let url = storage.fileURLWithName(fileName)
          for await playback in audioPlayer.play(url) {
            switch playback {
            case let .playing(position):
              await send(.progressUpdated(position.progress))
            case let .pause(position):
              await send(.progressUpdated(position.progress))
            case .stop:
              break
            case let .error(error):
              log.error(error as Any)
              // TODO: Show alert with error
              await send(.audioPlayerClient(.failure(error ?? NSError())))
            case let .finish(successful):
              await send(.audioPlayerClient(.success(successful)))
            }
          }
        }
        .cancellable(id: PlayID.self, cancelInFlight: true)

      case .playing:
        state.mode = .notPlaying
        return .fireAndForget { await audioPlayer.pause() }
          .merge(with: .cancel(id: PlayID.self))
      }

    case let .progressUpdated(progress):
      switch state.mode {
      case .notPlaying:
        break
      case .playing:
        state.mode = .playing(progress: progress)
      }
      return .none
    }
  }
}

extension RecordingCard.State.Mode {
  var isPlaying: Bool {
    if case .playing = self { return true }
    return false
  }

  var progress: Double? {
    if case let .playing(progress) = self { return progress }
    return nil
  }
}

extension ViewStore where ViewState == RecordingCard.State {
  var currentTime: TimeInterval {
    state.mode.progress.map { $0 * state.recordingInfo.duration } ?? state.recordingInfo.duration
  }
}

// MARK: - RecordingCardView

struct RecordingCardView: View {
  let store: StoreOf<RecordingCard>

  var body: some View {
    WithViewStore(store) { viewStore in
      VStack(spacing: .grid(1)) {
        VStack(spacing: .grid(1)) {
          HStack(spacing: .grid(3)) {
            PlayButton(isPlaying: viewStore.mode.isPlaying) {
              viewStore.send(.playButtonTapped)
            }

            VStack(alignment: .leading, spacing: 0) {
              TextField("Untitled",
                        text: .constant(""))//viewStore.binding(get: \.recordingInfo.title, send: { .titleTextFieldChanged($0) }))
                .font(.DS.bodyM)
                .foregroundColor(Color.DS.Text.base)
              Text(viewStore.recordingInfo.date.formatted(date: .abbreviated, time: .shortened))
                .font(.DS.date)
                .foregroundColor(Color.DS.Text.subdued)
            }

            dateComponentsFormatter.string(from: viewStore.currentTime).map {
              Text($0)
                .font(.DS.date)
                .foregroundColor(viewStore.mode.isPlaying
                  ? Color.DS.Text.base
                  : Color.DS.Text.subdued)
            }
          }

          WaveformProgressView(
            audioURL: StorageClient.liveValue.fileURLWithName(viewStore.recordingInfo.fileName),
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

extension StringProtocol {
  /// Removes the given delimiter string from both the start and the end of this string if and only if it starts with and ends with the delimiter.
  /// Otherwise returns this string unchanged.
  func removingSurrounding(_ character: Character) -> SubSequence {
    guard count > 1, first == character, last == character else {
      return self[...]
    }
    return dropFirst().dropLast()
  }
}
