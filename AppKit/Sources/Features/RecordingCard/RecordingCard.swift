import ComposableArchitecture
import Foundation

// MARK: - RecordingCard

@Reducer
struct RecordingCard {
  @ObservableState
  struct State: Equatable, Identifiable, Then {
    var id: String { recording.id }

    var index: Int
    @Shared var recording: RecordingInfo
    var playerControls: PlayerControls.State
    @Presents var alert: AlertState<Action.Alert>?
    @Shared(.transcriptionTasks) private var taskQueue: [TranscriptionTask]

    var queuePosition: Int? {
      taskQueue.firstIndex(where: { $0.recordingInfoID == recording.id }).map { $0 + 1 }
    }

    var queueTotal: Int? { taskQueue.count }

    var isTranscribing: Bool { recording.isTranscribing }
    var transcribingProgressText: String { recording.transcription?.text ?? "" }
    var isInQueue: Bool { queuePosition != nil && queueTotal != nil }

    var transcription: String {
      recording.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(index: Int, recording: Shared<RecordingInfo>) {
      self.index = index
      _recording = recording
      playerControls = .init(recording: recording)
    }
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case playerControls(PlayerControls.Action)
    case transcribeTapped
    case cancelTranscriptionTapped
    case titleChanged(String)
    case recordingSelected
    case didTapResumeTranscription
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable {}

    enum Delegate: Equatable {
      case didTapTranscribe(RecordingInfo)
      case didTapResumeTranscription(RecordingInfo)
    }
  }

  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  @Dependency(StorageClient.self) var storage: StorageClient

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

      case .transcribeTapped:
        logs.debug("Transcribe tapped for recording \(state.recording.id)")
        // Handled in RootStore
        return .send(.delegate(.didTapTranscribe(state.recording)))

      case .cancelTranscriptionTapped:
        state.recording.transcription?.status = .canceled
        return .run { [state] _ in
          await transcriptionWorker.cancelTaskForRecordingID(state.recording.id)
        }

      case let .titleChanged(title):
        state.recording.title = title
        return .none

      case .recordingSelected:
        return .none

      case .didTapResumeTranscription:
        return .send(.delegate(.didTapResumeTranscription(state.recording)))

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
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
    case let .paused(_, progress):
      "Paused (\(String(format: "%.0f", progress * 100))%)"
    }
  }
}
