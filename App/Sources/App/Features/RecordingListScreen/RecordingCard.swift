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

    public var id: String { recordingInfo.id }
    @BindingState var recordingInfo: RecordingInfo
    @BindingState var mode = Mode.notPlaying
    @BindingState var isTranscribing = false
    @BindingState var isExpanded = false
    @BindingState var transcribingProgressText: String = ""
    @BindingState var alert: AlertState<Action>?

    var waveFormImageURL: URL?
    var waveform: WaveformProgress.State {
      get {
        WaveformProgress.State(
          fileName: recordingInfo.fileName,
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
  }

  public enum Action: BindableAction, Equatable {
    case task
    case binding(BindingAction<State>)
    case audioPlayerFinished(TaskResult<Bool>)
    case playButtonTapped
    case progressUpdated(Double)
    case waveform(WaveformProgress.Action)
    case transcribeTapped
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.storage) var storage
  @Dependency(\.settings) var settings: SettingsClient
  @Dependency(\.backgroundProcessingClient) var backgroundProcessingClient: BackgroundProcessingClient

  private enum PlayID {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Scope(state: \.waveform, action: /Action.waveform) {
      WaveformProgress()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        return subscribeToTranscriptionState(filename: state.recordingInfo.fileName)

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
        guard transcriber.transcriberState().isIdle else {
          state.alert = .error(message: "Transcription is already in progress")
          return .none
        }

        return .fireAndForget { [recordingId = state.recordingInfo.id] in
          Task { @MainActor in
            backgroundProcessingClient.startTask(recordingId)
          }
        }
      }
    }
  }

  private func subscribeToTranscriptionState(filename: String) -> EffectTask<Action> {
    .run { send in
      for await state in transcriber.getTranscriptionStateStream(filename) {
        log.debug("Transcription state: \(state?.state.message ?? "nil")")
        if let state {
          switch state.state {
          case .starting, .loadingModel, .transcribing:
            await send(.binding(.set(\.$isTranscribing, true)))
            var currentText = state.segments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            currentText = currentText.isEmpty ? state.state.message : currentText
            await send(.binding(.set(\.$transcribingProgressText, currentText)))
          case .finished:
            await send(.binding(.set(\.$isTranscribing, false)))
            await send(.binding(.set(\.$recordingInfo.text, state.text)))
            await send(.binding(.set(\.$recordingInfo.isTranscribed, true)))
          case .error:
            await send(.binding(.set(\.$isTranscribing, false)))
            await send(.binding(.set(\.$alert, .error(message: state.state.message))))
          }
        } else {
          await send(.binding(.set(\.$isTranscribing, false)))
        }
      }
    }
  }

  private func play(state: inout State) -> EffectPublisher<Action, Never> {
    state.mode = .playing(progress: 0)

    return .run { [fileName = state.recordingInfo.fileName] send in
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
          await send(.binding(.set(\.$alert,
                                   AlertState<Action>(
                                     title: TextState("Error"),
                                     message: TextState(error?.localizedDescription ?? "Something went wrong.")
                                   ))))
          await send(.audioPlayerFinished(.failure(error ?? NSError())), animation: .default)
        case let .finish(successful):
          await send(.audioPlayerFinished(.success(successful)), animation: .default)
        }
      }
    }
    .cancellable(id: PlayID.self, cancelInFlight: true)
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

extension TranscriptionState.State {
  var message: String {
    switch self {
    case .starting:
      return "Starting transcription..."
    case .loadingModel:
      return "Loading model..."
    case .transcribing:
      return "Transcribing..."
    case .finished:
      return "Finished"
    case .error:
      return "Error"
    }
  }
}
