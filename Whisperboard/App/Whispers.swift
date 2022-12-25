import AVFoundation
import ComposableArchitecture
import SwiftUI

struct Whispers: ReducerProtocol {
  struct State: Equatable {
    var alert: AlertState<Action>?
    var audioRecorderPermission = RecorderPermission.undetermined
    var recording: Recording.State?
    var whispers: IdentifiedArrayOf<Whisper.State> = []
    var isTranscribing = false
    var transcribingIdInProgress: Whisper.State.ID?
    var expandedWhisperId: Whisper.State.ID?

    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }
  }

  enum Action: Equatable {
    case readStoredWhispers
    case setWhispers(TaskResult<IdentifiedArrayOf<Whisper.State>>)
    case alertDismissed
    case openSettingsButtonTapped
    case recordButtonTapped
    case recordPermissionResponse(Bool)
    case recording(Recording.Action)
    case whisper(id: Whisper.State.ID, action: Whisper.Action)
    case gearButtonTapped
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
    Reduce { state, action in
      switch action {
      case .readStoredWhispers:
        return .task {
          try? await self.storage.cleanup()
          return await .setWhispers(TaskResult { try await self.storage.read() })
        }
          .animation()

      case let .setWhispers(result):
        switch result {
        case let .success(value):
          state.whispers = value
        case let .failure(error):
          log(error)
        }
        return .none

      case .alertDismissed:
        state.alert = nil
        return .none

      case .openSettingsButtonTapped:
        return .fireAndForget {
          await self.openSettings()
        }

      case .recordButtonTapped:
        switch state.audioRecorderPermission {
        case .undetermined:
          return .task {
            await .recordPermissionResponse(self.requestRecordPermission())
          }

        case .denied:
          state.alert = AlertState(
            title: TextState("Permission is required to record voice.")
          )
          return .none

        case .allowed:
          state.recording = newRecording
          return .none
        }

      case let .recording(.delegate(.didFinish(.success(recording)))):
        state.recording = nil
        let whisper = Whisper.State(
          date: recording.date,
          duration: recording.duration,
          fileName: recording.url.lastPathComponent
        )
        state.whispers.insert(whisper, at: 0)
        let id = whisper.id
        return .task { .transcribeWhisper(id: id) }
          .merge(with: .cancel(id: Recording.CancelID()))

      case .recording(.delegate(.didFinish(.failure))):
        state.alert = AlertState(title: TextState("Voice recording failed."))
        state.recording = nil
        return .cancel(id: Recording.CancelID())

      case .recording:
        return .none

      case let .recordPermissionResponse(permission):
        state.audioRecorderPermission = permission ? .allowed : .denied
        if permission {
          state.recording = newRecording
          return .none
        } else {
          state.alert = AlertState(
            title: TextState("Permission is required to record voice.")
          )
          return .none
        }

      case .whisper(id: _, action: .audioPlayerClient(.failure)):
        state.alert = AlertState(title: TextState("Voice playback failed."))
        return .none

      case let .whisper(id: id, action: .delete):
        state.whispers.remove(id: id)
        return .none

      case let .whisper(id: tappedId, action: .playButtonTapped):
        for id in state.whispers.ids where id != tappedId {
          state.whispers[id: id]?.mode = .notPlaying
        }
        return .none

      case .gearButtonTapped:
        return .none

      case let .transcribeWhisper(id):
        guard !state.isTranscribing else { return .none }

        state.isTranscribing = true
        state.transcribingIdInProgress = id
        return .task {
          await .transcriptionFinished(
            id: id,
            TaskResult { try await self.transcriber.transcribeAudio(self.storage.fileURLWithName(id)) }
          )
        }
          .animation()

      case let .whisper(id, .bodyTapped):
        guard !state.isTranscribing else { return .none }

        guard let whisper = state.whispers[id: id] else { return .none }

        if !whisper.isTranscribed {
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
        state.isTranscribing = false
        switch result {
        case let .success(text):
          state.whispers[id: id]?.text = text
          state.whispers[id: id]?.isTranscribed = true
          state.expandedWhisperId = id

        case let .failure(error):
          state.alert = AlertState(title: TextState("Error while transcribing voice recording"), message: TextState(error.localizedDescription))
        }
        return .none
      }
    }
      .ifLet(\.recording, action: /Action.recording) {
        Recording()
      }
      .forEach(\.whispers, action: /Action.whisper(id:action:)) {
        Whisper()
      }
      .onChange(of: \.whispers) { whispers, state, _ -> Effect<Action, Never> in
        log("whispers changed")
        return .fireAndForget {
          try await self.storage.write(whispers)
        }
      }
  }

  private var newRecording: Recording.State {
    Recording.State(
      date: self.date.now,
      url: storage.createNewWhisperURL()
    )
  }
}

struct WhispersView: View {
  let store: StoreOf<Whispers>
  @ObservedObject var viewStore: ViewStoreOf<Whispers>

  init(store: StoreOf<Whispers>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    NavigationView {
      ZStack {
        whisperList()
          .frame(maxHeight: .infinity, alignment: .top)

        recordingControls()
          .frame(maxHeight: .infinity, alignment: .bottom)
      }
        .background(ColorPalette.darkness)
        .alert(
          self.store.scope(state: \.alert),
          dismiss: .alertDismissed
        )
        .navigationTitle("Whispers")
      // .navigationBarItems(
      //   trailing: Button { viewStore.send(.gearButtonTapped) }
      //   label: { Image(systemName: "gearshape") }
      // )
    }
      .navigationViewStyle(.stack)
      .task { await viewStore.send(.readStoredWhispers).finish() }
  }

  func whisperList() -> some View {
    List {
      ForEachStore(
        self.store.scope(state: \.whispers, action: { .whisper(id: $0, action: $1) })
      ) { childStore in
        whisperRowView(childStore)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }
        .onDelete { indexSet in
          for index in indexSet {
            viewStore.send(.whisper(id: viewStore.whispers[index].id, action: .delete))
          }
        }
        .buttonStyle(PlainButtonStyle())
    }
  }

  func recordingControls() -> some View {
    IfLetStore(
      self.store.scope(state: \.recording, action: { .recording($0) })
    ) { store in
      RecordingView(store: store)
    } else: {
      RecordButton(permission: viewStore.audioRecorderPermission) {
        viewStore.send(.recordButtonTapped, animation: .spring())
      } settingsAction: {
        viewStore.send(.openSettingsButtonTapped)
      }
    }
      .padding()
      .frame(maxWidth: .infinity)
  }

  func whisperRowView(_ childStore: StoreOf<Whisper>) -> some View {
    let childState = ViewStore(childStore).state
    return VStack(spacing: 0) {
      WhisperView(store: childStore)
        .overlay(alignment: .bottom) {
          ZStack {
            if viewStore.isTranscribing, viewStore.transcribingIdInProgress == childState.id {
              Color.black.opacity(0.5)
              ActivityIndicator()
                .frame(width: 20, height: 20)
            }
          }
            .frame(height: 50)
        }

      ZStack {
        if viewStore.expandedWhisperId == childState.id {
          VStack(spacing: .grid(1)) {
            HStack {
              CopyButton(text: childState.text)
              ShareButton(text: childState.text)
            }

            Text(childState.text)
              .textSelection(.enabled)
          }
            .padding(.grid(1))
            .transition(
              AnyTransition.move(edge: .top)
                .combined(with: AnyTransition.scale)
            )
        }
      }
        .animation(.easeInOut(duration: 0.3), value: viewStore.isTranscribing)
        .animation(.easeInOut(duration: 0.3), value: viewStore.expandedWhisperId)
    }
      .background {
        ZStack {
          if viewStore.expandedWhisperId == childState.id {
            ColorPalette.background
              .cornerRadius(.grid(2), corners: [.bottomLeft, .bottomRight])
          }
        }
      }
  }
}

struct CopyButton: View {
  var text: String

  var body: some View {
    Button {
      UIPasteboard.general.string = text
    } label: {
      Image(systemName: "doc.on.clipboard")
        .foregroundColor(ColorPalette.orangeRed)
        .padding(.grid(1))
    }
  }
}

struct ShareButton: View {
  var text: String

  var body: some View {
    Button {
      let text = text
      let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)

      UIApplication.shared.windows.first?.rootViewController?.present(activityController, animated: true, completion: nil)
    } label: {
      Image(systemName: "paperplane")
        .foregroundColor(ColorPalette.orangeRed)
        .padding(.grid(1))
    }
  }
}

struct RecordButton: View {
  let permission: Whispers.State.RecorderPermission
  let action: () -> Void
  let settingsAction: () -> Void

  var body: some View {
    ZStack {
      Button(action: self.action) {
        Circle()
          .fill(ColorPalette.orangeRed)
          .overlay {
            Image(systemName: "mic")
              .resizable()
              .scaledToFit()
              .frame(width: 30, height: 30)
              .foregroundColor(ColorPalette.darkness)
          }
      }
        .frame(width: 70, height: 70)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.grid(3))
        .opacity(self.permission == .denied ? 0.1 : 1)

      if self.permission == .denied {
        VStack(spacing: 10) {
          Text("Recording requires microphone access.")
            .multilineTextAlignment(.center)
          Button("Open Settings", action: self.settingsAction)
        }
          .frame(maxWidth: .infinity, maxHeight: 74)
      }
    }
  }
}
