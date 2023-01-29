import AppDevUtils
import AVFoundation
import ComposableArchitecture
import SwiftUI

// MARK: - WhisperList

struct WhisperList: ReducerProtocol {
  struct State: Equatable, Then {
    var alert: AlertState<Action>?
    var whispers: IdentifiedArrayOf<Whisper.State> = []
    var isTranscribing = false
    var transcribingIdInProgress: Whisper.State.ID?
    var expandedWhisperId: Whisper.State.ID?
    var settings = Settings.State()
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case readStoredWhispers
    case setRecordings(TaskResult<IdentifiedArrayOf<RecordingInfo>>)
    case alertDismissed
    case whisper(id: Whisper.State.ID, action: Whisper.Action)
    case transcribeWhisper(id: Whisper.State.ID)
    case transcriptionFinished(id: Whisper.State.ID, TaskResult<String>)
  }

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.date) var date
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.uuid) var uuid
  @Dependency(\.storage) var storage
  @Dependency(\.transcriber) var transcriber

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .readStoredWhispers:
        return .task {
          await .setRecordings(TaskResult { try await storage.read() })
        }
        .animation()

      case let .setRecordings(result):
        switch result {
        case let .success(value):
          state.whispers = value.map(Whisper.State.init(recordingInfo:)).identifiedArray

        case let .failure(error):
          log(error)
          state.alert = AlertState(title: TextState("Failed to read recordings."), message: TextState(error.localizedDescription))
        }
        return .none

      case .whisper(id: _, action: .audioPlayerClient(.failure)):
        state.alert = AlertState(title: TextState("Voice playback failed."))
        return .none

      case let .whisper(id: id, action: .delete):
        state.whispers.remove(id: id)
        return .none

      case let .whisper(id: id, action: .retryTranscription):
        return .task { .transcribeWhisper(id: id) }

      case let .whisper(id: tappedId, action: .playButtonTapped):
        for id in state.whispers.ids where id != tappedId {
          state.whispers[id: id]?.mode = .notPlaying
        }
        return .none

      case let .transcribeWhisper(id):
        guard !state.isTranscribing else { return .none }
        guard let modelURL = state.settings.modelSelector.selectedModel?.type.localURL else {
          state.alert = AlertState(title: TextState("Model not selected."), message: TextState("Please select a model in the settings."))
          return .none
        }

        state.isTranscribing = true
        state.transcribingIdInProgress = id
        return .task {
          await .transcriptionFinished(
            id: id,
            TaskResult { try await transcriber.transcribeAudio(storage.fileURLWithName(id), modelURL) }
          )
        }
        .animation()

      case let .whisper(id, .bodyTapped):
        guard !state.isTranscribing else { return .none }

        guard let whisper = state.whispers[id: id] else { return .none }

        if !whisper.recordingInfo.isTranscribed {
          return .task { .transcribeWhisper(id: id) }
        } else {
          if state.expandedWhisperId == id {
            state.expandedWhisperId = nil
          } else {
            state.expandedWhisperId = id
          }
          return .none
        }

      case .whisper:
        return .none

      case let .transcriptionFinished(id, result):
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        state.isTranscribing = false
        switch result {
        case let .success(text):
          state.whispers[id: id]?.recordingInfo.text = text
          state.whispers[id: id]?.recordingInfo.isTranscribed = true
          state.expandedWhisperId = id

        case let .failure(error):
          state.alert = AlertState(title: TextState("Error while transcribing voice recording"), message: TextState(error.localizedDescription))
        }
        return .none

      case .alertDismissed:
        state.alert = nil
        return .none
      }
    }
    .forEach(\.whispers, action: /Action.whisper(id:action:)) {
      Whisper()
    }
    .onChange(of: \.whispers) { whispers, _, _ -> EffectTask<Action> in
      .fireAndForget {
        try await storage.write(whispers.map(\.recordingInfo).identifiedArray)
      }
    }
  }
}

// MARK: - WhisperListView

struct WhisperListView: View {
  let store: StoreOf<WhisperList>
  @ObservedObject var viewStore: ViewStoreOf<WhisperList>

  init(store: StoreOf<WhisperList>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    NavigationStack {
      whisperList()
        .frame(maxHeight: .infinity, alignment: .top)
        .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
        .navigationTitle("Recordings")
        .navigationBarTitleDisplayMode(.inline)
        .background(LinearGradient.screenBackground)
    }
    .task { await viewStore.send(.readStoredWhispers).finish() }
    .accentColor(Color.DS.Background.accent)
  }

  func whisperList() -> some View {
    ScrollView {
      LazyVStack(spacing: .grid(8)) {
        ForEachStore(
          store.scope(state: \.whispers, action: { .whisper(id: $0, action: $1) })
        ) { childStore in
          whisperRowView(childStore)
        }
      }
      .padding(.horizontal, .grid(4))
    }
  }

  func whisperRowView(_ childStore: StoreOf<Whisper>) -> some View {
    let childState = ViewStore(childStore).state
    let isTranscribing = viewStore.isTranscribing && viewStore.transcribingIdInProgress == childState.id
    return WhisperView(store: childStore, isTranscribing: isTranscribing)
  }
}

// MARK: - WhisperListView_Previews

struct WhisperListView_Previews: PreviewProvider {
  static var previews: some View {
    WhisperListView(
      store: Store(
        initialState: WhisperList.State(),
        reducer: WhisperList()
      )
    )
  }
}
