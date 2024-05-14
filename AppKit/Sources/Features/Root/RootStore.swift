import BackgroundTasks
import Combine
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
  struct State: Equatable {
    var transcriptionWorker = TranscriptionWorker.State()
    var recordingListScreen = RecordingListScreen.State()
    var recordScreen = RecordScreen.State()
    var settingsScreen = SettingsScreen.State()
    var path = StackState<Path.State>()
    var selectedTab: Tab = .record

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
    case failedICloudSync(EquatableError)
    case registerForBGProcessingTasks(BGProcessingTask)

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

    Scope(state: \.transcriptionWorker, action: \.transcriptionWorker) {
      TranscriptionWorker()
    }

    Scope(state: \.recordingListScreen, action: \.recordingListScreen) {
      RecordingListScreen()
    }

    Scope(state: \.recordScreen, action: \.recordScreen) {
      RecordScreen()
    }

    Scope(state: \.settingsScreen, action: \.settingsScreen) {
      SettingsScreen()
    }
    .onChange(of: \.settingsScreen.settings.isICloudSyncEnabled) { _, _ in
      Reduce { state, _ in
        uploadNewRecordingsToICloud(state)
      }
    }

    Reduce { state, action in
      switch action {
      case .task:
        subscriptionClient.configure(keychainClient.userID)

        // Pausing unfinished transcription on app launch
        for recording in state.recordingListScreen.recordings {
          if let transcription = recording.transcription, transcription.status.isLoadingOrProgress {
            if let task = state.transcriptionWorker.taskQueue[id: transcription.id] {
              logs.debug("Marking \(recording.fileName) transcription as paused")
              state.recordingListScreen.recordings[id: recording.id]?.transcription?.status = .paused(task, progress: recording.progress)
            } else {
              logs.debug("Marking \(recording.fileName) transcription as failed")
              state.recordingListScreen.recordings[id: recording.id]?.transcription?.status = .error(message: "Transcription failed")
            }
            state.transcriptionWorker.taskQueue[id: transcription.id] = nil
          }
        }

        return .none

      case .settingsScreen(.binding(.set(\.settings.isICloudSyncEnabled, true))):
        return uploadNewRecordingsToICloud(state)

      case let .recordScreen(.delegate(.newRecordingCreated(recordingInfo))):
        state.recordingListScreen.recordings.append(recordingInfo)
        return .run { [state] send in
          try await Task.sleep(for: .seconds(1))
          if state.settingsScreen.settings.isAutoTranscriptionEnabled {
            await send(.transcriptionWorker(.enqueueTaskForRecordingID(recordingInfo.id, state.settingsScreen.settings)))
          }
        }.merge(with: uploadNewRecordingsToICloud(state))

      case .path(.element(_, .details(.delegate(.deleteDialogConfirmed)))):
        guard let id = state.path.last?.details?.recordingCard.id else { return .none }
        state.recordingListScreen.recordings.removeAll(where: { $0.id == id })
        return .none

      case .recordScreen(.delegate(.goToNewRecordingTapped)):
        if let recordingCard = state.recordingListScreen.recordingCards.first {
          state.selectedTab = .list
          state.path.append(.details(RecordingDetails.State(recordingCard: recordingCard)))
        }
        return .none

      case .settingsScreen(.alert(.presented(.deleteDialogConfirmed))):
        state.path.removeAll()
        return .none

      case .recordingListScreen(.didFinishImportingFiles):
        return uploadNewRecordingsToICloud(state)

      case let .failedICloudSync(error):
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

      case let .recordingListScreen(.recordingCard(.element(_, .delegate(.enqueueTaskForRecordingID(recordingID))))),
           let .path(.element(_, .details(.recordingCard(.delegate(.enqueueTaskForRecordingID(recordingID)))))):
        return .run { [state] send in
          await send(.transcriptionWorker(.enqueueTaskForRecordingID(recordingID, state.settingsScreen.settings)))
        }

      case let .recordingListScreen(.recordingCard(.element(_, .delegate(.cancelTaskForRecordingID(recordingID))))),
           let .path(.element(_, .details(.recordingCard(.delegate(.cancelTaskForRecordingID(recordingID)))))):
        return .run {  send in
          await send(.transcriptionWorker(.cancelTaskForRecordingID(recordingID)))
        }

      case let .recordingListScreen(.recordingCard(.element(_, .delegate(.resumeTask(task))))),
           let .path(.element(_, .details(.recordingCard(.delegate(.resumeTask(task)))))):
        return .run {  send in
          await send(.transcriptionWorker(.resumeTask(task)))
        }

      default:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .forEach(\.path, action: \.path)
  }

  func uploadNewRecordingsToICloud(_ state: State) -> Effect<Action> {
    .run { send in
      if state.settingsScreen.settings.isICloudSyncEnabled {
        await send(.settingsScreen(.set(\.isICloudSyncInProgress, true)))
        try await storage.uploadRecordingsToICloud(false, state.recordingListScreen.recordings)
        await send(.settingsScreen(.set(\.isICloudSyncInProgress, false)))
      }
    } catch: { error, send in
      await send(.settingsScreen(.set(\.isICloudSyncInProgress, false)))
      await send(.failedICloudSync(error.equatable))
    }
  }
}
