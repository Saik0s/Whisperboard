import Combine
import ComposableArchitecture
import SwiftUI

// MARK: - Root

@Reducer
struct Root {
  enum Tab: Int { case list, record, settings }

  @Reducer(state: .equatable)
  public enum Path {
    case details(RecordingDetails)
  }

  @ObservableState
  struct State: Equatable {
    @Shared(.transcriptionTasks) var taskQueue: [TranscriptionTask]
    var recordingListScreen = RecordingListScreen.State()
    var recordScreen = RecordScreen.State()
    var settingsScreen = SettingsScreen.State()
    var path = StackState<Path.State>()
    var selectedTab: Tab = .record

    @Presents var alert: AlertState<Action.Alert>?

    var isRecording: Bool {
      recordScreen.recordingControls.recording != nil
    }

    var isTranscribing: Bool {
      recordingListScreen.recordings.contains { $0.isTranscribing }
    }

    var shouldDisableIdleTimer: Bool {
      isRecording || isTranscribing
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case recordingListScreen(RecordingListScreen.Action)
    case recordScreen(RecordScreen.Action)
    case settingsScreen(SettingsScreen.Action)
    case path(StackActionOf<Path>)
    case task
    case selectTab(Int)
    case alert(PresentationAction<Alert>)
    case failedICloudSync(EquatableError)

    enum Alert: Hashable {}
  }

  @Dependency(StorageClient.self) var storage: StorageClient
  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient
  @Dependency(\.keychainClient) var keychainClient: KeychainClient
  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.recordingListScreen, action: \.recordingListScreen) {
      RecordingListScreen()
    }

    Scope(state: \.recordScreen, action: \.recordScreen) {
      RecordScreen()
    }

    Scope(state: \.settingsScreen, action: \.settingsScreen) {
      SettingsScreen()
    }
    .onChange(of: \.settingsScreen.settings.isICloudSyncEnabled) { oldValue, newValue in
      Reduce { state, _ in
        uploadNewRecordingsToICloud(state)
      }
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        subscriptionClient.configure(keychainClient.userID)

        for recording in state.recordingListScreen.$recordings.elements {
          if let transcription = recording.wrappedValue.transcription, transcription.status.isLoadingOrProgress {
            if let taskIndex = state.taskQueue.firstIndex(where: { $0.id == transcription.id }) {
              logs.debug("Marking \(recording.wrappedValue.fileName) last transcription as paused")
              recording.wrappedValue.transcription?.status = .paused(state.taskQueue[taskIndex], progress: recording.wrappedValue.progress)
              state.taskQueue[taskIndex].isPaused = true
            } else {
              logs.debug("Marking \(recording.wrappedValue.fileName) last transcription as failed")
              recording.wrappedValue.transcription?.status = .error(message: "Transcription failed")
            }
          }
        }
        return .none

      case let .path(.element(_, .details(.recordingCard(.delegate(.didTapTranscribe(recording)))))),
           let .recordingListScreen(.recordingCard(.element(_, .delegate(.didTapTranscribe(recording))))):
        return .run { [state] _ in
          await transcriptionWorker.enqueueTaskForRecordingID(recording.id, state.settingsScreen.settings)
        }

      case let .path(.element(_, .details(.recordingCard(.delegate(.didTapResumeTranscription(recording)))))),
           let .recordingListScreen(.recordingCard(.element(_, .delegate(.didTapResumeTranscription(recording))))):
        return .run { _ in
          if let transcription = recording.transcription, case let .paused(task, _) = transcription.status {
            await transcriptionWorker.resumeTask(task)
          }
        }

      case let .recordScreen(.newRecordingCreated(recordingInfo)):
        state.recordingListScreen.recordings.append(recordingInfo)
        return .run { [state] _ in
          if state.settingsScreen.settings.isAutoTranscriptionEnabled {
            await transcriptionWorker.enqueueTaskForRecordingID(recordingInfo.id, state.settingsScreen.settings)
          }
        }.merge(with: uploadNewRecordingsToICloud(state))

      case .path(.element(_, .details(.delegate(.deleteDialogConfirmed)))):
        guard let id = state.path.last?.details?.recordingCard.id else { return .none }
        state.recordingListScreen.recordings.removeAll(where: { $0.id == id })
        return .none

      case .recordScreen(.goToNewRecordingTapped):
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

      case let .recordingListScreen(.recordingCard(.element(id, .recordingSelected))):
        guard let card = state.recordingListScreen.recordingCards[id: id] else { return .none }
        state.path.append(.details(RecordingDetails.State(recordingCard: card)))
        return .none

      case let .selectTab(tab):
        state.selectedTab = .init(rawValue: tab) ?? .list
        return .none

      case let .failedICloudSync(error):
        logs.error("Failed to sync with iCloud: \(error)")
        state.alert = .init(
          title: .init("Failed to sync with iCloud"),
          message: .init(error.localizedDescription),
          dismissButton: .default(.init("OK"))
        )
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .forEach(\.path, action: \.path)
    .onChange(of: \.shouldDisableIdleTimer) { _, shouldDisableIdleTimer in
      Reduce { _, _ in
        UIApplication.shared.isIdleTimerDisabled = shouldDisableIdleTimer
        return .none
      }
    }
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
