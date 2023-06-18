import AppDevUtils
import ComposableArchitecture
import Foundation

// MARK: - RecordingCard

public struct RecordingCard: ReducerProtocol {
  public struct State: Equatable, Identifiable, Then {
    enum Mode: Equatable, Codable {
      case notPlaying
      case playing(progress: Double)
    }

    public var id: String { recordingEnvelop.id }

    var recordingEnvelop: RecordingEnvelop

    var mode = Mode.notPlaying

    var isTranscribing: Bool { recordingEnvelop.transcriptionState?.isTranscribing ?? false }

    var transcribingProgressText: String { recordingEnvelop.transcriptionState?.segments.map(\.text).joined(separator: " ") ?? "" }

    @BindingState var alert: AlertState<Action>?

    var waveFormImageURL: URL?

    var waveform: WaveformProgress.State {
      get {
        WaveformProgress.State(
          fileName: recordingEnvelop.fileName,
          progress: mode.progress ?? 0,
          isPlaying: mode.isPlaying,
          waveFormImageURL: waveFormImageURL
        )
      }
      set {
        waveFormImageURL = newValue.waveFormImageURL
        if mode.isPlaying {
          mode = .playing(progress: newValue.progress)
        }
      }
    }

    public init(recordingEnvelop: RecordingEnvelop) {
      self.recordingEnvelop = recordingEnvelop
    }
  }

  public enum Action: BindableAction, Equatable {
    case task
    case binding(BindingAction<State>)
    case audioPlayerFinished(TaskResult<Bool>)
    case playButtonTapped
    case progressUpdated(Double)
    case waveform(WaveformProgress.Action)
    case transcribeTapped
    case cancelTranscriptionTapped
    case titleChanged(String)
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient

  @Dependency(\.audioPlayer) var audioPlayer: AudioPlayerClient

  @Dependency(\.storage) var storage: StorageClient

  @Dependency(\.settings) var settings: SettingsClient

  @Dependency(\.backgroundProcessingClient) var backgroundProcessingClient: BackgroundProcessingClient

  private struct PlayID: Hashable {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Scope(state: \.waveform, action: /Action.waveform) {
      WaveformProgress()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        return .none

      case .binding:
        return .none

      case .audioPlayerFinished:
        state.mode = .notPlaying
        return .cancel(id: PlayID.self)

      case .playButtonTapped:
        guard state.mode.isPlaying == false else {
          state.mode = .notPlaying
          return .fireAndForget { await audioPlayer.pause() }
            .merge(with: .cancel(id: PlayID.self))
        }

        return play(state: &state)

      case let .progressUpdated(progress):
        if state.mode.isPlaying {
          state.mode = .playing(progress: progress)
        }
        return .none

      case let .waveform(.didTouchAtHorizontalLocation(progress)):
        guard state.mode.isPlaying else { return .none }
        return .fireAndForget { await audioPlayer.seekProgress(progress) }

      case .waveform:
        return .none

      case .transcribeTapped:
        log.debug("Transcribe tapped for recording \(state.recordingEnvelop.id)")
        return .run { [id = state.recordingEnvelop.id] _ in
          try await backgroundProcessingClient.startTask(id)
        } catch: { error, send in
          #if DEBUG
            await send(.binding(.set(\.$alert, .error(error))))
          #else
            await send(.binding(.set(\.$alert, .genericError)))
          #endif
        }

      case .cancelTranscriptionTapped:
        return .fireAndForget(priority: .utility) {
          backgroundProcessingClient.removeAndCancelAllTasks()
        }

      case let .titleChanged(title):
        do {
          try storage.update(state.recordingEnvelop.id) { $0.title = title }
        } catch {
          log.error(error)
          state.alert = .error(message: "Failed to update title")
        }
        return .none
      }
    }
  }

  private func play(state: inout State) -> EffectPublisher<Action, Never> {
    state.mode = .playing(progress: 0)

    return .run { [fileName = state.recordingEnvelop.fileName] send in
      let url = storage.audioFileURLWithName(fileName)
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
          await send(.binding(.set(\.$alert, .error(message: "Failed to play audio"))))
          await send(.audioPlayerFinished(.failure(error ?? NSError())), animation: .default)
        case let .finish(successful):
          await send(.audioPlayerFinished(.success(successful)), animation: .default)
        }
      }
    }
    .cancellable(id: PlayID(), cancelInFlight: true)
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

extension TranscriptionState.Progress {
  var message: String {
    switch self {
    case .starting:
      return "Starting transcription..."
    case .loadingModel:
      return "Loading model..."
    case .transcribing:
      return "Transcribing..."
    case let .finished(result):
      return result
    case let .error(error):
      return error.localizedDescription
    }
  }
}
