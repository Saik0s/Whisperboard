import Combine
import ComposableArchitecture
import SwiftUI

// MARK: - Root

@Reducer
struct Root {
  enum Tab: Int { case list, record, settings }

  @ObservableState
  struct State: Equatable {
    var recordingListScreen = RecordingListScreen.State()
    var recordScreen = RecordScreen.State()
    var settingsScreen = SettingsScreen.State()

    var selectedTab: Tab = .record
    @Presents var alert: AlertState<Action.Alert>?

    var isRecording: Bool {
      recordScreen.recordingControls.recording != nil
    }

    var isTranscribing: Bool {
      recordingListScreen.recordingCards.map(\.recording).contains { $0.isTranscribing }
    }

    var shouldDisableIdleTimer: Bool {
      isRecording || isTranscribing
    }
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case task
    case recordingListScreen(RecordingListScreen.Action)
    case recordScreen(RecordScreen.Action)
    case settingsScreen(SettingsScreen.Action)
    case selectTab(Int)
    case updateTranscription(Transcription)
    case alert(PresentationAction<Alert>)
    case failedToUpdateRecording(RecordingInfo.ID, EquatableError)
    case failedICloudSync(EquatableError)

    enum Alert: Hashable {}
  }

  @Dependency(\.storage) var storage: StorageClient
  @Dependency(\.settings) var settings: SettingsClient
  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    CombineReducers {
      Scope(state: \.recordingListScreen, action: /Action.recordingListScreen) {
        RecordingListScreen()
      }

      Scope(state: \.recordScreen, action: /Action.recordScreen) {
        RecordScreen()
      }

      Scope(state: \.settingsScreen, action: /Action.settingsScreen) {
        SettingsScreen()
      }

      Reduce<State, Action> { state, action in
        switch action {
        case .recordScreen(.goToNewRecordingTapped):
          if let recordingCard = state.recordingListScreen.recordingCards.first {
            state.selectedTab = .list
            state.recordingListScreen.selection = .init(recordingCard: recordingCard)
          }
          return .none

        case .settingsScreen(.alert(.presented(.deleteDialogConfirmed))):
          state.recordingListScreen.selection = nil
          return .none

        case .recordingListScreen(.didFinishImportingFiles), .recordScreen(.newRecordingCreated):
          return .run { send in
            if settings.getSettings().isICloudSyncEnabled {
              await send(.settingsScreen(.set(\.isICloudSyncInProgress, true)))
              try await storage.uploadRecordingsToICloud(false)
              await send(.settingsScreen(.set(\.isICloudSyncInProgress, false)))
            }
          } catch: { error, send in
            await send(.failedICloudSync(error.equatable))
          }

        default:
          return .none
        }
      }

      Reduce { _, action in
        switch action {
        case let .recordingListScreen(.details(action: .presented(.recordingCard(.delegate(.didTapTranscribe(recording)))))),
             let .recordingListScreen(.recordingCard(
               _,
               .delegate(.didTapTranscribe(recording))
             )):
          enqueueTranscriptionTask(recording: recording)
          return .none

        case let .recordingListScreen(.details(action: .presented(.recordingCard(.delegate(.didTapResume(recording)))))),
             let .recordingListScreen(.recordingCard(
               _,
               .delegate(.didTapResume(recording))
             )):
          if let transcription = recording.lastTranscription, case let .paused(task) = transcription.status {
            resumeTranscriptionTask(task: task)
          }
          return .none

        case let .recordScreen(.newRecordingCreated(recordingInfo)):
          if settings.getSettings().isAutoTranscriptionEnabled {
            enqueueTranscriptionTask(recording: recordingInfo)
          }
          return .run { send in
            if settings.getSettings().isICloudSyncEnabled {
              await send(.settingsScreen(.set(\.isICloudSyncInProgress, true)))
              try await storage.uploadRecordingsToICloud(false)
              await send(.settingsScreen(.set(\.isICloudSyncInProgress, false)))
            }
          } catch: { error, send in
            await send(.failedICloudSync(error.equatable))
          }

        default:
          return .none
        }
      }

      Reduce<State, Action> { state, action in
        switch action {
        case .task:
          return .run { send in
            // If there are any recordings that are in progress, but not in the queue, mark them as failed
            let queue = transcriptionWorker.getTasks()
            let recordings = storage.read().map { recording in
              if let transcription = recording.lastTranscription, transcription.status.isLoadingOrProgress {
                var recording = recording
                if let task = queue.first(where: { $0.id == transcription.id }) {
                  log.debug("Marking \(recording.fileName) last transcription as paused")
                  recording.transcriptionHistory[id: transcription.id]?.status = .paused(task)
                } else {
                  log.debug("Marking \(recording.fileName) last transcription as failed")
                  recording.transcriptionHistory[id: transcription.id]?.status = .error(message: "Transcription failed")
                }
                return recording
              }
              return recording
            }.identifiedArray
            storage.write(recordings)
            await transcriptionWorker.cancelAllTasks()

            await send(.recordingListScreen(.task))
            for await transcription in transcriptionWorker.transcriptionStream() {
              log.debug(transcription.status)
              await send(.updateTranscription(transcription))
            }
          }

        case let .updateTranscription(transcription):
          return .run { _ in
            try storage.update(transcription.fileName) { recording in
              if !recording.transcriptionHistory.contains(where: { $0.id == transcription.id }) {
                recording.editedText = nil
              }
              recording.transcriptionHistory[id: transcription.id] = transcription
            }
          } catch: { error, send in
            await send(.failedToUpdateRecording(transcription.fileName, error.equatable))
          }

        case let .selectTab(tab):
          state.selectedTab = .init(rawValue: tab) ?? .list
          return .none

        case let .failedToUpdateRecording(fileName, error):
          log.error("Failed to update transcription for \(fileName): \(error)")
          state.alert = .init(
            title: .init("Failed to update recording"),
            message: .init(error.localizedDescription),
            dismissButton: .default(.init("OK"))
          )
          return .none

        case let .failedICloudSync(error):
          log.error("Failed to sync with iCloud: \(error)")
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
    }
    .ifLet(\.$alert, action: \.alert)
    .onChange(of: \.shouldDisableIdleTimer) { _, shouldDisableIdleTimer in
      Reduce { _, _ in
        UIApplication.shared.isIdleTimerDisabled = shouldDisableIdleTimer
        return .none
      }
    }
  }

  private func enqueueTranscriptionTask(recording: RecordingInfo) {
    let settings = settings.getSettings()
    transcriptionWorker.enqueueTaskForRecording(recording, settings)
  }

  private func resumeTranscriptionTask(task: TranscriptionTask) {
    transcriptionWorker.resumeTask(task)
  }
}
