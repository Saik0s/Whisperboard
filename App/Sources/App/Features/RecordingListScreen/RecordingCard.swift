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
    case binding(BindingAction<State>)
    case audioPlayerFinished(TaskResult<Bool>)
    case playButtonTapped
    case progressUpdated(Double)
    case waveform(WaveformProgress.Action)
    case transcribeTapped
    case alertDismissed
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient
  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.storage) var storage

  private enum PlayID {}

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
        let fileURL = storage.audioFileURLWithName(state.recordingInfo.fileName)

        return .run { send in
          await send(.binding(.set(\.$isTranscribing, true)))
          await send(.binding(.set(\.$recordingInfo.isTranscribed, false)))
          await send(.binding(.set(\.$recordingInfo.text, "")))

          var lastText = ""
          for try await text in transcriber.transcribeAudio(url: fileURL, language: .auto) {
            await send(.binding(.set(\.$transcribingProgressText, text)))
            lastText = text
          }
          await send(.binding(.set(\.$recordingInfo.text, lastText)))

          await send(.binding(.set(\.$recordingInfo.isTranscribed, true)))
          await send(.binding(.set(\.$isTranscribing, false)))
        } catch: { error, send in
          log.error(error)
          await send(.binding(.set(\.$alert, AlertState<Action>(title: TextState("Error"), message: TextState(error.localizedDescription)))))
          await send(.binding(.set(\.$isTranscribing, false)))
        }.animation(.default)

      case .alertDismissed:
        state.alert = nil
        return .none
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
