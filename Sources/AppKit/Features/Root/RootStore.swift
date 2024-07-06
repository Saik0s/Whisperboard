import BackgroundTasks
import Combine
import Common
import ComposableArchitecture
import DependenciesAdditions
import SwiftUI

// MARK: - Root

@Reducer
struct Root {
  enum Tab: Equatable { case list, record, settings }

  @Reducer(state: .equatable)
  public enum Path {
    case details(RecordingDetails)
  }

  @ObservableState
  struct State {
    var transcriptionWorker = TranscriptionWorker.State()
    var recordingListScreen = RecordingListScreen.State()
    var recordScreen = RecordScreen.State()
    var settingsScreen = SettingsScreen.State()
    var path = StackState<Path.State>()
    var selectedTab: Tab = .record
    var isGoToNewRecordingPopupPresented = false

    @Presents var alert: AlertState<Action.Alert>?

    var isRecording: Bool { recordScreen.recordingControls.recording != nil }
    var isTranscribing: Bool { transcriptionWorker.isProcessing }
    var shouldDisableIdleTimer: Bool { isRecording || isTranscribing }
  }

  enum Action: BindableAction {
    case task
    case binding(BindingAction<State>)
    case transcriptionWorker(TranscriptionWorker.Action)
    case recordingListScreen(RecordingListScreen.Action)
    case recordScreen(RecordScreen.Action)
    case settingsScreen(SettingsScreen.Action)
    case path(StackActionOf<Path>)
    case alert(PresentationAction<Alert>)
    case didCompleteICloudSync(TaskResult<Void>)
    case registerForBGProcessingTasks(BGProcessingTask)
    case goToNewRecordingButtonTapped

    enum Alert: Equatable {}
  }

  @Dependency(StorageClient.self) var storage: StorageClient
  @Dependency(\.keychainClient) var keychainClient: KeychainClient
  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient
  @Dependency(\.application) var application: Application

  var body: some Reducer<State, Action> {
    BindingReducer()
      .onChange(of: \.shouldDisableIdleTimer) { _, shouldDisableIdleTimer in
        Reduce { _, _ in
          .run { _ in
            await MainActor.run { application.isIdleTimerDisabled = shouldDisableIdleTimer }
          }
        }
      }
      .onChange(of: \.recordScreen.recordingControls.recording?.recordingInfo.fileURL) { _, url in
        Reduce { _, _ in
          storage.setCurrentRecordingURL(url: url)
          return .none
        }
      }

    Scope(state: \.transcriptionWorker, action: \.transcriptionWorker) {
      TranscriptionWorker()
    }

    Scope(state: \.recordingListScreen, action: \.recordingListScreen) {
      RecordingListScreen()
    }

    Scope(state: \.recordScreen, action: \.recordScreen) {
      RecordScreen()
        ._printChanges(.swiftLog(withStateChanges: true))
    }

    Scope(state: \.settingsScreen, action: \.settingsScreen) {
      SettingsScreen()
        ._printChanges(.swiftLog(withStateChanges: true))
    }

    Reduce { state, action in
      switch action {
      case .task:
        // Pausing unfinished transcription on app launch
        for recording in state.recordingListScreen.recordings {
          if let transcription = recording.transcription, transcription.status.isLoadingOrProgress {
            logs.debug("Marking \(recording.fileName) transcription as failed")
            state.recordingListScreen.recordings[id: recording.id]?.transcription?.status = .error(message: "Transcription failed, please try again.")
            state.transcriptionWorker.taskQueue[id: transcription.id] = nil
          }
        }

        return .run { _ in
          subscriptionClient.configure(keychainClient.userID)
        }

      case .recordingListScreen(.didFinishImportingFiles),
           .settingsScreen(.binding(.set(\.settings.isICloudSyncEnabled, true))):
        return .run { send in
          await send(.didCompleteICloudSync(TaskResult { try await uploadNewRecordingsToICloudIfNeeded() }))
        }

      // Inserts a new recording into the recording list and enqueues a transcription task if auto-transcription is enabled
      case let .recordScreen(.delegate(.newRecordingCreated(recordingInfo))):
        state.recordingListScreen.recordings.insert(recordingInfo, at: 0)
        state.isGoToNewRecordingPopupPresented = true

        return .run { send in
          await send(.didCompleteICloudSync(TaskResult { try await uploadNewRecordingsToICloudIfNeeded() }))
        }

      case .path(.element(_, .details(.delegate(.deleteDialogConfirmed)))):
        guard let id = state.path.last?.details?.recordingCard.id else { return .none }
        state.recordingListScreen.recordings.removeAll(where: { $0.id == id })
        state.path.removeLast()
        return .none

      case .settingsScreen(.alert(.presented(.deleteStorageDialogConfirmed))):
        state.path.removeAll()
        return .none

      case .didCompleteICloudSync(.success):
        return .none

      case let .didCompleteICloudSync(.failure(error)):
        logs.error("Failed to sync with iCloud: \(error)")
        state.alert = .init(
          title: .init("Failed to sync with iCloud"),
          message: .init(error.localizedDescription),
          dismissButton: .default(.init("OK"))
        )
        return .none

      case let .registerForBGProcessingTasks(task):
        return .run { send in
          await send(.transcriptionWorker(.handleBGProcessingTask(task)))
        }

      case let .path(.element(_, .details(.recordingCard(.delegate(.enqueueTaskForRecordingID(recordingID)))))),
           let .recordingListScreen(.recordingCard(.element(_, .delegate(.enqueueTaskForRecordingID(recordingID))))):
        return .run { [state] send in
          await send(.transcriptionWorker(.enqueueTaskForRecordingID(recordingID, state.settingsScreen.settings)))
        }

      case let .path(.element(_, .details(.recordingCard(.delegate(.cancelTaskForRecordingID(recordingID)))))),
           let .recordingListScreen(.recordingCard(.element(_, .delegate(.cancelTaskForRecordingID(recordingID))))):
        return .run { send in
          await send(.transcriptionWorker(.cancelTaskForRecordingID(recordingID)))
        }

      case let .path(.element(_, .details(.recordingCard(.delegate(.resumeTask(task)))))),
           let .recordingListScreen(.recordingCard(.element(_, .delegate(.resumeTask(task))))):
        return .run { send in
          await send(.transcriptionWorker(.resumeTask(task)))
        }

      case .goToNewRecordingButtonTapped:
        if let recordingCard = state.recordingListScreen.recordingCards.first {
          state.selectedTab = .list
          state.path.append(.details(RecordingDetails.State(recordingCard: recordingCard)))
        }
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .forEach(\.path, action: \.path)
  }

  func uploadNewRecordingsToICloudIfNeeded() async throws {
    @Shared(.settings) var settings: Settings
    @Shared(.recordings) var recordings: [RecordingInfo]
    @Shared(.isICloudSyncInProgress) var isICloudSyncInProgress: Bool

    if settings.isICloudSyncEnabled {
      $isICloudSyncInProgress.withLock { $0 = true }
      defer { $isICloudSyncInProgress.withLock { $0 = false } }
      try await storage.uploadRecordingsToICloud(reset: false, recordings: recordings)
    }
  }
}
