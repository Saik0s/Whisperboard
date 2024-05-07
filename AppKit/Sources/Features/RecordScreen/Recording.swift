import ComposableArchitecture
import SwiftUI

// MARK: - Recording

@Reducer
struct Recording {
  @ObservableState
  struct State: Equatable {
    enum Mode {
      case recording, encoding, paused, removing
    }

    var recordingInfo: RecordingInfo
    var mode: Mode = .recording
    var samples: [Float] = []

    var url: URL { recordingInfo.fileURL }
    var duration: TimeInterval { recordingInfo.duration }
    var date: Date { recordingInfo.date }
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
    case recordingSamplesCollected(TimeInterval, [Float])
  }

  enum DelegateAction: Equatable {
    case didFinish(TaskResult<State>)
    case didCancel
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .task:
      state.mode = .recording
      UIImpactFeedbackGenerator(style: .light).impactOccurred()

      return .run { [url = state.url, audioRecorder] send in
        var sampleBatch: [Float] = []
        var lastDuration: TimeInterval = 0

        for await recState in await audioRecorder.startRecording(url) {
          if case let .recording(duration, power) = recState {
            let linear = 1 - pow(10, power / 20)
            sampleBatch.append(contentsOf: [linear])
            lastDuration = duration

            if sampleBatch.count >= 12 {
              await send(.recordingSamplesCollected(lastDuration, sampleBatch))
              sampleBatch.removeAll()
            }
          } else {
            if !sampleBatch.isEmpty {
              await send(.recordingSamplesCollected(lastDuration, sampleBatch))
              sampleBatch.removeAll()
            }
            await send(.recordingStateUpdated(recState))
          }
        }
      }

    case .delegate:
      return .none

    case let .finalRecordingTime(duration):
      state.recordingInfo.duration = duration
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

    case .recordingStateUpdated(.recording):
      return .none

    case let .recordingSamplesCollected(duration, samples):
      state.recordingInfo.duration = duration
      state.samples.append(contentsOf: samples)
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
