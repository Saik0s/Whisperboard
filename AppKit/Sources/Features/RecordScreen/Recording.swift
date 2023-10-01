
import ComposableArchitecture
import SwiftUI

// MARK: - Recording

struct Recording: ReducerProtocol {
  struct State: Equatable {
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

  enum Action: Equatable {
    case task
    case delegate(DelegateAction)
    case finalRecordingTime(TimeInterval)
    case saveButtonTapped
    case pauseButtonTapped
    case continueButtonTapped
    case deleteButtonTapped
    case recordingStateUpdated(RecordingState)
  }

  enum DelegateAction: Equatable {
    case didFinish(TaskResult<State>)
    case didCancel
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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

    case .saveButtonTapped:
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      state.mode = .encoding

      return .run { send in
        await send(.finalRecordingTime(audioRecorder.currentTime()))
        await audioRecorder.stopRecording()
      }

    case .pauseButtonTapped:
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      state.mode = .paused

      return .run { [audioRecorder] _ in
        await audioRecorder.pauseRecording()
      }

    case .continueButtonTapped:
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      state.mode = .recording

      return .run { [audioRecorder] _ in
        await audioRecorder.continueRecording()
      }

    case .deleteButtonTapped:
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      state.mode = .removing

      return .run { [audioRecorder] _ in
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
      return .run { send in
        await send(.delegate(.didFinish(.failure(error))))
      }

    case let .recordingStateUpdated(.finished(successfully)):
      return .run { [state] send in
        guard state.mode == .encoding else {
          await send(.delegate(.didCancel))
          return
        }

        if successfully {
          await send(.delegate(.didFinish(.success(state))))
        } else {
          await send(.delegate(.didFinish(.failure(Failed()))))
        }
      }
    }
  }
}
