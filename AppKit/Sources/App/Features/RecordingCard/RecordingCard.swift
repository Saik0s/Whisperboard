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

    public var id: String { recording.id }

    var recording: RecordingInfo
    var mode = Mode.notPlaying
    var waveFormImageURL: URL?
    var queuePosition: Int?
    var queueTotal: Int?

    var isTranscribing: Bool { recording.isTranscribing }
    var transcribingProgressText: String { recording.lastTranscription?.text ?? "" }
    var isInQueue: Bool { queuePosition != nil && queueTotal != nil }

    @BindingState var alert: AlertState<Action>?

    var waveform: WaveformProgress.State {
      get {
        WaveformProgress.State(
          fileName: recording.fileName,
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

    public init(recording: RecordingInfo) {
      self.recording = recording
    }
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case audioPlayerFinished(TaskResult<Bool>)
    case playButtonTapped
    case progressUpdated(Double)
    case waveform(WaveformProgress.Action)
    case transcribeTapped
    case cancelTranscriptionTapped
    case titleChanged(String)
  }

  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  @Dependency(\.audioPlayer) var audioPlayer: AudioPlayerClient
  @Dependency(\.storage) var storage: StorageClient
  @Dependency(\.settings) var settings: SettingsClient

  private struct PlayID: Hashable {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Scope(state: \.waveform, action: /Action.waveform) {
      WaveformProgress()
    }

    Reduce<State, Action> { state, action in
      switch action {
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
        log.debug("Transcribe tapped for recording \(state.recording.id)")
        let fileURL = storage.audioFileURLWithName(state.recording.fileName)
        let parameters = settings.getSettings().parameters
        let model = settings.getSettings().selectedModel
        let task = TranscriptionTask(fileURL: fileURL, parameters: parameters, modelType: model)
        return .run { _ in
          await transcriptionWorker.enqueueTask(task)
        }

      case .cancelTranscriptionTapped:
        state.queuePosition = nil
        state.queueTotal = nil
        return .run { [state] _ in
          await transcriptionWorker.cancelTaskForFile(state.recording.fileName)
          try storage.update(state.recording.id) { recording in
            if let last = recording.transcriptionHistory.last, last.status.isLoadingOrProgress {
              recording.transcriptionHistory[id: last.id]?.status = .canceled
            }
          }
        } catch: { error, _ in
          log.error(error)
        }

      case let .titleChanged(title):
        do {
          try storage.update(state.recording.id) { $0.title = title }
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

    return .run { [fileName = state.recording.fileName] send in
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

extension RecordingCard.State {
  var dateString: String {
    recording.date.formatted(date: .abbreviated, time: .shortened)
  }

  var currentTimeString: String {
    let currentTime = mode.progress.map { $0 * recording.duration } ?? recording.duration
    return dateComponentsFormatter.string(from: currentTime) ?? ""
  }

  var transcription: String {
    recording.text.trimmingCharacters(in: .whitespacesAndNewlines)
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

extension Transcription.Status {
  var message: String {
    switch self {
    case .notStarted:
      return "Waiting to start..."
    case .loading:
      return "Loading model..."
    case let .error(message: message):
      return message
    case let .progress(progress):
      return "Transcribing... \(Int(progress * 100))%"
    case .done:
      return "Done"
    case .canceled:
      return "Canceled"
    }
  }
}
