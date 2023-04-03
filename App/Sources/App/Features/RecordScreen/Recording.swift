import AppDevUtils
import ComposableArchitecture
import SwiftUI

// MARK: - Recording

public struct Recording: ReducerProtocol {
  public struct State: Equatable {
    var date: Date
    var duration: TimeInterval = 0
    var mode: Mode = .recording
    var url: URL
    var samples: [Float] = []

    enum Mode {
      case recording
      case encoding
      case paused
      case removing
    }
  }

  public enum Action: Equatable {
    case task
    case delegate(DelegateAction)
    case finalRecordingTime(TimeInterval)
    case stopButtonTapped
    case pauseButtonTapped
    case continueButtonTapped
    case deleteButtonTapped
    case recordingStateUpdated(RecordingState)
  }

  public enum DelegateAction: Equatable {
    case didFinish(TaskResult<State>)
    case didCancel
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.continuousClock) var clock

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .task:
      state.mode = .recording
      UIImpactFeedbackGenerator(style: .light).impactOccurred()

      return .run { [url = state.url, audioRecorder] send in
        await audioRecorder.startRecording(url)

        for await recState in await audioRecorder.recordingState() {
          await send(.recordingStateUpdated(recState))
        }
      }

    case .delegate:
      return .none

    case let .finalRecordingTime(duration):
      state.duration = duration
      return .none

    case .stopButtonTapped:
      state.mode = .encoding
      UIImpactFeedbackGenerator(style: .light).impactOccurred()

      return .run { send in
        await send(.finalRecordingTime(audioRecorder.currentTime()))
        await audioRecorder.stopRecording()
      }

    case .pauseButtonTapped:
      state.mode = .paused
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.pauseRecording()
      }

    case .continueButtonTapped:
      state.mode = .recording
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.continueRecording()
      }

    case .deleteButtonTapped:
      state.mode = .removing
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.removeCurrentRecording()
      }

    case let .recordingStateUpdated(.recording(duration, power)):
      state.duration = duration
      let linear = 1 - pow(10, power / 20)
      state.samples.append(contentsOf: [linear, linear, linear])
      return .none

    case .recordingStateUpdated(.paused):
      state.mode = .paused
      return .none

    case .recordingStateUpdated(.stopped):
      state.mode = .encoding
      return .none

    case let .recordingStateUpdated(.error(error)):
      return .task { .delegate(.didFinish(.failure(error))) }

    case let .recordingStateUpdated(.finished(successfully)):
      return .task { [state] in
        guard state.mode == .encoding else {
          return .delegate(.didCancel)
        }

        if successfully {
          return .delegate(.didFinish(.success(state)))
        } else {
          return .delegate(.didFinish(.failure(Failed())))
        }
      }
    }
  }
}
