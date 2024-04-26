import ComposableArchitecture
import Foundation

// MARK: - RecordingCard

@Reducer
struct RecordingCard {
  @ObservableState
  struct State: Equatable, Identifiable, Then {
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

    var id: String { recording.id }

    var index: Int
    var recording: RecordingInfo
    var mode = Mode.notPlaying
    var waveFormImageURL: URL?
    var queuePosition: Int?
    var queueTotal: Int?

    var isTranscribing: Bool { recording.isTranscribing }
    var transcribingProgressText: String { recording.lastTranscription?.text ?? "" }
    var isInQueue: Bool { queuePosition != nil && queueTotal != nil }

    @Presents var alert: AlertState<Action.Alert>?

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

    init(recording: RecordingInfo, index: Int) {
      self.recording = recording
      self.index = index
    }
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case audioPlayerFinished(TaskResult<Bool>)
    case playButtonTapped
    case progressUpdated(Double)
    case waveform(WaveformProgress.Action)
    case transcribeTapped
    case cancelTranscriptionTapped
    case titleChanged(String)
    case recordingSelected
    case resumeTapped
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable {}

    enum Delegate: Equatable {
      case didTapTranscribe(RecordingInfo)
      case didTapResume(RecordingInfo)
    }
  }

  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  @Dependency(\.audioPlayer) var audioPlayer: AudioPlayerClient
  @Dependency(\.storage) var storage: StorageClient
  @Dependency(\.settings) var settings: SettingsClient

  private struct PlayID: Hashable {}

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.waveform, action: /Action.waveform) {
      WaveformProgress()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case let .audioPlayerFinished(result):
        state.mode = .notPlaying
        if case .failure = result {
          state.alert = .error(message: "Failed to play audio")
        }
        return .cancel(id: PlayID())

      case .playButtonTapped:
        guard state.mode.isPlaying == false else {
          state.mode = .notPlaying
          return .run { _ in
            await audioPlayer.pause()
          }
          .merge(with: .cancel(id: PlayID()))
        }

        return play(state: &state)

      case let .progressUpdated(progress):
        if state.mode.isPlaying {
          state.mode = .playing(progress: progress)
        }
        return .none

      case let .waveform(.didTouchAtHorizontalLocation(progress)):
        guard state.mode.isPlaying else { return .none }
        return .run { _ in
          await audioPlayer.seekProgress(progress)
        }

      case .waveform:
        return .none

      case .transcribeTapped:
        logs.debug("Transcribe tapped for recording \(state.recording.id)")
        // Handled in RootStore
        return .send(.delegate(.didTapTranscribe(state.recording)))

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
          logs.error("Failed to cancel transcription: \(error)")
        }

      case let .titleChanged(title):
        do {
          try storage.update(state.recording.id) { $0.title = title }
        } catch {
          logs.error("Failed to update title: \(error)")
          state.alert = .error(message: "Failed to update title")
        }
        return .none

      case .recordingSelected:
        return .none

      case .resumeTapped:
        return .send(.delegate(.didTapResume(state.recording)))

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
  }

  private func play(state: inout State) -> Effect<Action> {
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
          logs.error("Failed to play audio: \(error as Any)")
          await send(.audioPlayerFinished(.failure(error ?? NSError())), animation: .default)

        case let .finish(successful):
          await send(.audioPlayerFinished(.success(successful)), animation: .default)
        }
      }
    }
    .cancellable(id: PlayID(), cancelInFlight: true)
  }
}

extension Transcription.Status {
  var message: String {
    switch self {
    case .notStarted:
      "Waiting to start..."
    case .loading:
      "Loading model..."
    case let .uploading(progress):
      "Uploading... \(String(format: "%.0f", progress * 100))%"
    case let .error(message: message):
      message

    case let .progress(progress):
      "Transcribing... \(String(format: "%.0f", progress * 100))%"
    case .done:
      "Done"
    case .canceled:
      "Canceled"
    case let .paused(task):
      "Paused (\(String(format: "%.0f", task.progress * 100))%)"
    }
  }
}
