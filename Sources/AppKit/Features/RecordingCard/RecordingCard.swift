import Common
import ComposableArchitecture
import Foundation

// MARK: - RecordingCard

@Reducer
struct RecordingCard {
  struct QueueInfo: Equatable {
    let position: Int
    let total: Int
  }

  @ObservableState
  struct State: Equatable, Identifiable, Then {
    var id: String { recording.id }

    @Shared var recording: RecordingInfo
    @SharedReader var queueInfo: QueueInfo?
    var playerControls: PlayerControls.State

    var isInQueue: Bool { queueInfo != nil }
    var transcription: String { recording.text }

    init(recording: Shared<RecordingInfo>, queueInfo: SharedReader<QueueInfo?>) {
      _recording = recording
      playerControls = .init(recording: recording)
      _queueInfo = queueInfo
    }
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case playerControls(PlayerControls.Action)
    case transcribeButtonTapped
    case cancelTranscriptionButtonTapped
    case recordingSelected
    case didTapResumeTranscription
    case delegate(DelegateAction)

    enum DelegateAction: Equatable {
      case enqueueTaskForRecordingID(String)
      case cancelTaskForRecordingID(String)
      case resumeTask(TranscriptionTask)
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.playerControls, action: \.playerControls) {
      PlayerControls()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .playerControls:
        return .none

      case .recordingSelected:
        return .none

      case .delegate:
        return .none

      case .transcribeButtonTapped:
        logs.debug("Transcribe tapped for recording \(state.recording.id)")
        return .send(.delegate(.enqueueTaskForRecordingID(state.recording.id)))

      case .cancelTranscriptionButtonTapped:
        state.recording.transcription?.status = .canceled
        return .send(.delegate(.cancelTaskForRecordingID(state.recording.id)))

      case .didTapResumeTranscription:
        if let transcription = state.recording.transcription, case let .paused(task, _) = transcription.status {
          return .send(.delegate(.resumeTask(task)))
        }
        return .none
      }
    }
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

    case let .progress(progress, _):
      "Transcribing... \(String(format: "%.0f", progress * 100))%"
    case .done:
      "Done"
    case .canceled:
      "Canceled"
    case let .paused(_, progress):
      "Paused (\(String(format: "%.0f", progress * 100))%)"
    }
  }
}
