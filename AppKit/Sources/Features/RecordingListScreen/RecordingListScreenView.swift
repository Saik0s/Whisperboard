import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Inject
import SwiftUI
import SwiftUIIntrospect

// MARK: - RecordingListScreen

@Reducer
struct RecordingListScreen {
  @ObservableState
  struct State: Equatable {
    @Shared(.recordings) var recordings: [RecordingInfo]

    var recordingCards: IdentifiedArrayOf<RecordingCard.State> = []
    var editMode: EditMode = .inactive
    var isImportingFiles = false

    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case task
    case recordingCard(IdentifiedActionOf<RecordingCard>)
    case delete(id: RecordingInfo.ID)
    case addFileRecordings(urls: [URL])
    case failedToAddRecordings(error: EquatableError)
    case alert(PresentationAction<Alert>)
    case didFinishImportingFiles
    case addRecordingInfo(RecordingInfo)
    case reloadCards
    case deleteSwipeActionTapped(RecordingInfo.ID)
    case didSyncRecordings(TaskResult<[RecordingInfo]>)

    enum Alert: Hashable {
      case deleteDialogConfirmed(id: RecordingInfo.ID)
    }
  }

  @Dependency(StorageClient.self) var storage: StorageClient
  @Dependency(\.fileImport) var fileImport: FileImportClient
  @Dependency(\.didBecomeActive) var didBecomeActive
  @Dependency(\.uuid) var uuid

  var body: some Reducer<State, Action> {
    BindingReducer()

    // Sync cards amount with recordings amount
    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        // Create initial recording cards
        state.recordingCards = createCards(for: state)

        return .run { [recordings = state.$recordings] send in
          await send(.didSyncRecordings(TaskResult { try await storage.sync(recordings.wrappedValue) }))
          for await _ in await didBecomeActive() {
            await send(.didSyncRecordings(TaskResult { try await storage.sync(recordings.wrappedValue) }))
          }
        }.merge(with: .run { [recordings = state.$recordings] send in
          for await _ in recordings.publisher.map({ $0.map(\.id) }).removeDuplicates().values {
            await send(.reloadCards)
          }
        })

      case let .addFileRecordings(urls):
        return .run { send in
          await send(.binding(.set(\.isImportingFiles, true)))

          for url in urls {
            let duration = try await getFileDuration(url: url)
            let recording = RecordingInfo(id: uuid().uuidString, title: url.lastPathComponent, date: Date(), duration: duration)
            logs.info("Importing file from \(url) to \(recording.fileURL)")
            try await fileImport.importFile(url, recording.fileURL)
            logs.info("Adding recording info: \(recording)")
            await send(.addRecordingInfo(recording))
          }

          await send(.binding(.set(\.isImportingFiles, false)))
          await send(.didFinishImportingFiles)
        } catch: { error, send in
          await send(.binding(.set(\.isImportingFiles, false)))
          await send(.failedToAddRecordings(error: error.equatable))
        }
        .animation(.gentleBounce())

      case let .addRecordingInfo(recording):
        state.recordings.insert(recording, at: 0)
        return .none

      case let .failedToAddRecordings(error):
        logs.error("Failed to add recordings error: \(error)")
        state.alert = .error(error)
        return .none

      case let .delete(id):
        createDeleteConfirmationDialog(id: id, state: &state)
        return .none

      case let .alert(.presented(.deleteDialogConfirmed(id))),
           let .deleteSwipeActionTapped(id):
        if let url = state.recordingCards[id: id]?.recording.fileURL {
          try? FileManager.default.removeItem(at: url)
        }
        state.recordingCards.removeAll { $0.id == id }
        state.recordings.removeAll { $0.id == id }

        return .none

      case .reloadCards:
        state.recordingCards = createCards(for: state)
        return .none

      case let .didSyncRecordings(.success(recordings)):
        state.recordings = recordings
        return .none

      case let .didSyncRecordings(.failure(error)):
        logs.error("Failed to sync recordings: \(error)")
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .forEach(\.recordingCards, action: \.recordingCard) {
      RecordingCard()
    }
  }

  private func createCards(for state: State) -> IdentifiedArrayOf<RecordingCard.State> {
    @SharedReader(.transcriptionTasks) var taskQueue: [TranscriptionTask]
    return state.$recordings.elements
      .map { recording in
        state.recordingCards[id: recording.id] ?? RecordingCard.State(
          recording: recording,
          queueInfo: $taskQueue.identifiedArray.elements[recordingInfoID: recording.id]
        )
      }
      .sorted(by: { $0.recording.date > $1.recording.date })
      .identifiedArray
  }

  private func createDeleteConfirmationDialog(id: RecordingInfo.ID, state: inout State) {
    state.alert = AlertState {
      TextState("Confirmation")
    } actions: {
      ButtonState(role: .destructive, action: .deleteDialogConfirmed(id: id)) {
        TextState("Delete")
      }
    } message: {
      TextState("Are you sure you want to delete this recording?")
    }
  }
}

// MARK: - RecordingListScreenView

struct RecordingListScreenView: View {
  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<RecordingListScreen>

  var body: some View {
    WithPerceptionTracking {
      ScrollView {
        LazyVStack {
          ForEach(store.scope(state: \.recordingCards, action: \.recordingCard)) { store in
            makeRecordingCard(store: store)
          }
          .removeClipToBounds()
        }
        .padding(.grid(4))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background {
        EmptyStateView()
          .hidden(!store.recordingCards.isEmpty)
      }
      .navigationTitle("Recordings")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarItems(
        leading: EditButton(),
        trailing: FilePicker(types: [.wav, .mp3, .mpeg4Audio], allowMultiple: true) { urls in
          store.send(.addFileRecordings(urls: urls))
        } label: {
          Image(systemName: "doc.badge.plus")
        }
        .secondaryIconButtonStyle()
      )
      .environment(
        \.editMode,
        $store.editMode
      )
      .removeNavigationBackground()
      .overlay {
        if store.isImportingFiles {
          Color.black.opacity(0.5).overlay(ProgressView())
        }
      }
      .animation(.hardShowHide(), value: store.recordingCards.count)
      .alert($store.scope(state: \.alert, action: \.alert))
      .applyTabBarContentInset()
    }
    .enableInjection()
  }
}

extension RecordingListScreenView {
  private func makeRecordingCard(store cardStore: StoreOf<RecordingCard>) -> some View {
    WithPerceptionTracking {
      HStack(spacing: .grid(4)) {
        RecordingCardView(store: cardStore)
          .scaleEffect(store.editMode.isEditing ? 0.85 : 1, anchor: .trailing)
          .background(alignment: .leading) {
            if store.editMode.isEditing {
              Button { store.send(.delete(id: cardStore.id)) } label: {
                Image(systemName: "multiply.circle.fill")
              }
              .iconButtonStyle()
            }
          }
      }
      .animation(.hardShowHide(), value: store.editMode.isEditing)
    }
  }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
  @ObserveInjection var inject

  @State private var isAnimating = false

  var body: some View {
    VStack(spacing: .grid(4)) {
      Image(systemName: "waveform.path.ecg")
        .font(.system(size: 100))
        .foregroundColor(.DS.Text.accent)
        .shadow(color: .DS.Text.accent.opacity(isAnimating ? 1 : 0), radius: isAnimating ? 20 : 0, x: 0, y: 0)
        .onAppear {
          withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.5)) {
            isAnimating.toggle()
          }
        }

      VStack(spacing: .grid(1)) {
        Text("No recordings yet")
          .textStyle(.bodyBold)
        Text("Your new recordings will appear here")
          .textStyle(.body)
      }
    }
    .padding(.grid(4))
    .enableInjection()
  }
}

private extension RandomAccessCollection where Element == TranscriptionTask, Index == Int {
  subscript(recordingInfoID id: RecordingInfo.ID) -> RecordingCard.QueueInfo? {
    firstIndex(where: { $0.recordingInfoID == id }).map { RecordingCard.QueueInfo(position: $0, total: self.count) }
  }
}
