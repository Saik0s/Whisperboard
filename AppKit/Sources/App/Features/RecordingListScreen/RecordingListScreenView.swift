import AppDevUtils
import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Inject
import SwiftUI
import SwiftUIIntrospect

// MARK: - RecordingListScreen

public struct RecordingListScreen: ReducerProtocol {
  public struct State: Equatable {
    var recordingCards: IdentifiedArrayOf<RecordingCard.State> = []

    var selectedId: RecordingInfo.ID? = nil

    @BindingState var editMode: EditMode = .inactive

    @BindingState var isImportingFiles = false

    @PresentationState var alert: AlertState<Action.Alert>?

    var selection: PresentationState<RecordingDetails.State> {
      get {
        guard let id = selectedId, let card = recordingCards[id: id]
        else { return PresentationState(wrappedValue: nil) }
        return PresentationState(wrappedValue: RecordingDetails.State(recordingCard: card))
      }
      set {
        selectedId = newValue.wrappedValue?.recordingCard.id
        if let card = newValue.wrappedValue?.recordingCard {
          recordingCards[id: card.id] = card
        }
      }
    }
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case task
    case receivedRecordings([RecordingInfo], IdentifiedArrayOf<TranscriptionTask>)
    case recordingCard(id: RecordingCard.State.ID, action: RecordingCard.Action)
    case delete(id: RecordingInfo.ID)
    case addFileRecordings(urls: [URL])
    case failedToAddRecordings(error: EquatableErrorWrapper)
    case details(action: PresentationAction<RecordingDetails.Action>)
    case recordingSelected(id: RecordingInfo.ID?)
    case alert(PresentationAction<Alert>)

    public enum Alert: Hashable {
      case deleteDialogConfirmed(id: RecordingInfo.ID)
    }
  }

  @Dependency(\.storage) var storage: StorageClient
  @Dependency(\.fileImport) var fileImport: FileImportClient
  @Dependency(\.transcriptionWorker) var transcriptionWorker: TranscriptionWorkerClient

  struct SavingRecordingsID: Hashable {}

  struct StreamID: Hashable {}

  public var body: some ReducerProtocol<State, Action> {
    CombineReducers {
      BindingReducer<State, Action>()

      mainReducer()

      deleteReducer()
    }
    .ifLet(\.selection, action: /Action.details) {
      RecordingDetails()
    }
    .forEach(\.recordingCards, action: /Action.recordingCard(id:action:)) {
      RecordingCard()
    }
  }

  private func mainReducer() -> some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        return .run { send in
          let stream = combineLatest(
            storage.recordingsInfoStream,
            transcriptionWorker.tasksStream()
          ).eraseToStream()

          for await value: (recordings: [RecordingInfo], tasksQueue: IdentifiedArrayOf<TranscriptionTask>) in stream {
            await send(.receivedRecordings(value.recordings, value.tasksQueue))
          }
        }
        .cancellable(id: StreamID(), cancelInFlight: true)

      case let .receivedRecordings(recordings, tasksQueue):
        state.recordingCards = recordings.map { recording in
          var card = state.recordingCards[id: recording.id] ?? RecordingCard.State(recording: recording)
          card.recording = recording
          if let index = tasksQueue.firstIndex(where: { $0.fileName == recording.fileName }) {
            card.queuePosition = index + 1
            card.queueTotal = tasksQueue.count
          } else {
            card.queuePosition = nil
            card.queueTotal = nil
          }
          return card
        }.identifiedArray

        let detailsState = state.selection.wrappedValue.flatMap { selection -> RecordingDetails.State? in
          guard let card = state.recordingCards.first(where: { $0.id == selection.recordingCard.id }) else {
            return nil
          }
          return RecordingDetails.State(recordingCard: card)
        }

        state.selection = PresentationState(wrappedValue: detailsState)

        return .none

      case .binding:
        return .none

      case .recordingCard:
        return .none

      case let .addFileRecordings(urls):
        return .run { send in
          await send(.binding(.set(\.$isImportingFiles, true)))

          for url in urls {
            let newURL = storage.createNewWhisperURL()
            log.verbose("Importing file from \(url) to \(newURL)")
            try await fileImport.importFile(url, newURL)

            let newFileName = newURL.lastPathComponent
            let oldFileName = url.lastPathComponent
            let duration = try getFileDuration(url: newURL)
            let recordingEnvelop = RecordingInfo(fileName: newFileName, title: oldFileName, date: Date(), duration: duration)
            log.verbose("Adding recording info: \(recordingEnvelop)")
            try await storage.addRecordingInfo(recordingEnvelop)
          }

          await send(.binding(.set(\.$isImportingFiles, false)))
        } catch: { error, send in
          await send(.binding(.set(\.$isImportingFiles, false)))
          await send(.failedToAddRecordings(error: error.equatable))
        }
        .animation(.gentleBounce())

      case let .failedToAddRecordings(error):
        log.error(error.error)
        state.alert = .error(error)
        return .none

      case .details:
        return .none

      case let .recordingSelected(id):
        state.selectedId = id
        return .none

      default:
        return .none
      }
    }
  }

  private func deleteReducer() -> some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case let .delete(id):
        createDeleteConfirmationDialog(id: id, state: &state)
        return .none

      case .details(action: .presented(.delete)):
        guard let id = state.selection.wrappedValue?.recordingCard.id else {
          return .none
        }
        createDeleteConfirmationDialog(id: id, state: &state)
        return .none

      case let .alert(.presented(.deleteDialogConfirmed(id))):
        if state.selection.wrappedValue?.recordingCard.id == id {
          state.selection = PresentationState(wrappedValue: nil)
        }

        do {
          try storage.delete(id)
        } catch {
          log.error(error)
          state.alert = .error(error)
        }
        return .none

      case .alert:
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
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

public struct RecordingListScreenView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordingListScreen>

  @ObservedObject var viewStore: ViewStoreOf<RecordingListScreen>

  var showListItems: Bool { !viewStore.recordingCards.isEmpty }

  public init(store: StoreOf<RecordingListScreen>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  public var body: some View {
    NavigationView {
      ScrollView {
        LazyVStack(spacing: .grid(4)) {
          ForEach(Array(viewStore.recordingCards.enumerated()), id: \.element.id) { index, card in
            IfLetStore(store.scope(
              state: \.recordingCards[id: card.id],
              action: { RecordingListScreen.Action.recordingCard(id: card.id, action: $0) }
            )) { store in
              makeRecordingCard(store: store, index: index, id: card.id)
            } else: {
              ProgressView()
            }
          }
        }
        .padding(.grid(4))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.default, value: viewStore.recordingCards.count)
        .removeClipToBounds()
      }
      .background {
        if viewStore.recordingCards.isEmpty {
          EmptyStateView()
        }
      }
      .navigationTitle("Recordings")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarItems(
        leading: EditButton(),
        trailing: FilePicker(types: [.wav, .mp3, .mpeg4Audio], allowMultiple: true) { urls in
          viewStore.send(.addFileRecordings(urls: urls))
        } label: {
          Image(systemName: "doc.badge.plus")
        }
        .secondaryIconButtonStyle()
      )
      .environment(
        \.editMode,
        viewStore.binding(\.$editMode)
      )
      .removeNavigationBackground()

      .sheet(
        store: store.scope(state: \.selection, action: RecordingListScreen.Action.details),
        content: RecordingDetailsView.init(store:)
      )
    }
    .overlay {
      if viewStore.isImportingFiles {
        Color.black.opacity(0.5).overlay(ProgressView())
      }
    }
    .messagePopup(store: store.scope(state: \.$alert, action: { .alert($0) }))
    .navigationViewStyle(.stack)
    .enableInjection()
  }
}

extension RecordingListScreenView {
  private func makeRecordingCard(store: StoreOf<RecordingCard>, index: Int, id: RecordingCard.State.ID) -> some View {
    HStack(spacing: .grid(4)) {
      if viewStore.editMode.isEditing {
        Button { viewStore.send(.delete(id: id)) } label: {
          Image(systemName: "multiply.circle.fill")
        }
        .iconButtonStyle()
      }

      Button { viewStore.send(.recordingSelected(id: id)) } label: {
        RecordingCardView(store: store)
          .offset(y: showListItems ? 0 : 500)
          .opacity(showListItems ? 1 : 0)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.75)
              .delay(Double(index) * 0.15),
            value: showListItems
          )
      }
      .cardButtonStyle()
      .animation(.gentleBounce(), value: viewStore.editMode.isEditing)
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
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
          isAnimating = true
        }
      VStack(spacing: .grid(1)) {
        Text("No recordings yet")
          .font(.DS.headlineL)
          .foregroundColor(.DS.Text.base)
        Text("Your new recordings will appear here")
          .font(.DS.bodyM)
          .foregroundColor(.DS.Text.base)
      }
    }
    .padding(.grid(4))
    .enableInjection()
  }
}

#if DEBUG

  struct RecordingListScreenView_Previews: PreviewProvider {
    static var previews: some View {
      RecordingListScreenView(
        store: Store(
          initialState: RecordingListScreen.State(),
          reducer: RecordingListScreen()
        )
      )
    }
  }
#endif
