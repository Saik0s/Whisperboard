import AppDevUtils
import Combine
import ComposableArchitecture
import SwiftUI

// MARK: - Root

struct Root: ReducerProtocol {
  enum Tab: Int { case list, record, settings }

  struct State: Equatable {
    var recordingListScreen = RecordingListScreen.State()
    var recordScreen = RecordScreen.State()
    var settings = SettingsScreen.State()
    @BindingState var selectedTab: Tab = .list
    var isRecording: Bool {
      recordScreen.recordingControls.recording != nil
    }

    var isTranscribing: Bool {
      recordingListScreen.recordingCards.map(\.isTranscribing).contains(true)
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
    case settings(SettingsScreen.Action)
    case selectTab(Int)
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient
  @Dependency(\.storage) var storage: StorageClient

  var body: some ReducerProtocol<State, Action> {
    CombineReducers {
      BindingReducer()
      Scope(state: \.recordingListScreen, action: /Action.recordingListScreen) {
        RecordingListScreen()
      }

      Scope(state: \.recordScreen, action: /Action.recordScreen) {
        RecordScreen()
      }

      Scope(state: \.settings, action: /Action.settings) {
        SettingsScreen()
      }

      Reduce<State, Action> { state, action in
        switch action {
        case .recordScreen(.goToNewRecordingTapped):
          if let recordingCard = state.recordingListScreen.recordingCards.first {
            state.selectedTab = .list
            state.recordingListScreen.selectedId = recordingCard.id
          }
          return .none

        case .settings(.deleteDialogConfirmed):
          state.recordingListScreen.selectedId = nil
          return .none

        default:
          return .none
        }
      }

      Reduce { state, action in
        switch action {
          case .task:
          return .task { .recordingListScreen(.task) }

        case let .selectTab(tab):
          state.selectedTab = .init(rawValue: tab) ?? .list
          return .none

        default:
          return .none
        }
      }
    }
    .onChange(of: \.shouldDisableIdleTimer) { shouldDisableIdleTimer, _, _ in
      UIApplication.shared.isIdleTimerDisabled = shouldDisableIdleTimer
      return .none
    }
  }
}
