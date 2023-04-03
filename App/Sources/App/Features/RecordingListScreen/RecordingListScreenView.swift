import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingListScreen

public struct RecordingListScreen: ReducerProtocol {
  public struct Row: Identifiable, Equatable {
    public var id: RecordingInfo.ID { card.id }

    var index: Int
    var card: RecordingCard.State
  }

  public struct State: Equatable {
    var recordings: IdentifiedArrayOf<RecordingCard.State> = []
    var recordingRows: IdentifiedArrayOf<Row> {
      recordings
        .enumerated()
        .map(Row.init(index:card:))
        .identifiedArray
    }

    var selection: Identified<RecordingInfo.ID, RecordingDetails.State>?

    @BindingState var editMode: EditMode = .inactive
    @BindingState var isImportingFiles = false

    @BindingState var alert: AlertState<Action>?
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case readStoredRecordings
    case setRecordings(TaskResult<IdentifiedArrayOf<RecordingInfo>>)
    case recording(id: RecordingCard.State.ID, action: RecordingCard.Action)
    case delete(id: RecordingInfo.ID)
    case plusButtonTapped
    case addFileRecordings(urls: [URL])
    case failedToAddRecordings(error: EquatableErrorWrapper)
    case deleteDialogConfirmed(id: RecordingInfo.ID)
    case details(action: RecordingDetails.Action)
    case recordingSelected(id: RecordingInfo.ID?)
  }

  @Dependency(\.storage) var storage: StorageClient
  @Dependency(\.fileImport) var fileImport: FileImportClient

  struct SavingRecordingsID: Hashable {}

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    CombineReducers {
      BindingReducer<State, Action>()

      Reduce<State, Action> { state, action in
        switch action {
        case .binding:
          return .none

        case .readStoredRecordings:
          return .task {
            await .setRecordings(TaskResult { try await storage.read() })
          }

        case let .setRecordings(.success(recordings)):
          state.recordings = recordings.map { info in
            state.recordings[id: info.id] ?? RecordingCard.State(recordingInfo: info)
          }.identifiedArray
          return .none

        case let .setRecordings(.failure(error)):
          state.alert = AlertState(title: TextState("Failed to read recordings."), message: TextState(error.localizedDescription))
          return .none

        case .recording:
          return .none

        case let .delete(id):
          createDeleteConfirmationDialog(id: id, state: &state)
          return .none

        case .details(action: .delete):
          guard let id = state.selection?.id else {
            return .none
          }
          createDeleteConfirmationDialog(id: id, state: &state)
          return .none

        case .plusButtonTapped:
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
              let recordingInfo = RecordingInfo(fileName: newFileName, title: oldFileName, date: Date(), duration: duration)
              log.verbose("Adding recording info: \(recordingInfo)")
              try await storage.addRecordingInfo(recordingInfo)
            }

            let recordings = try await storage.read()
            await send(.setRecordings(.success(recordings)))
            await send(.binding(.set(\.$isImportingFiles, false)))
          } catch: { error, send in
            await send(.binding(.set(\.$isImportingFiles, false)))
            await send(.failedToAddRecordings(error: error.equatable))
          }.animation(.gentleBounce())

        case let .failedToAddRecordings(error):
          log.error(error.error)
          state.alert = .error(error)
          return .none

        case let .deleteDialogConfirmed(id):
          guard let recording = state.recordings.first(where: { $0.id == id }) else {
            return .none
          }

          state.recordings.removeAll(where: { $0.id == id })
          if state.selection?.id == id {
            state.selection = nil
          }
          return .fireAndForget {
            try await storage.delete(recording.recordingInfo)
          }

        case .details:
          return .none

        case let .recordingSelected(id):
          guard let id else {
            state.selection = nil
            return .none
          }

          state.selection = state.recordings.first(where: { $0.id == id }).map { recording in
            Identified(RecordingDetails.State(recordingCard: recording), id: id)
          }
          return .none
        }
      }
    }
    .forEach(\.recordings, action: /Action.recording(id:action:)) {
      RecordingCard()
    }
    .ifLet(\.selection, action: /Action.details) {
      Scope(state: \Identified<RecordingInfo.ID, RecordingDetails.State>.value, action: /.self) {
        RecordingDetails()
      }
    }
    .onChange(of: \.selection) { selection, state, _ -> EffectTask<Action> in
      guard let selection else {
        return .none
      }
      state.recordings = state.recordings.map { recordingCard in
        recordingCard.id == selection.id ? selection.value.recordingCard : recordingCard
      }
      .identified()
      return .none
    }
    .onChange(of: \.recordings) { recordings, _, _ -> EffectTask<Action> in
      .fireAndForget {
        try await storage.write(recordings.map(\.recordingInfo).identifiedArray)
      }
      .cancellable(id: SavingRecordingsID(), cancelInFlight: true)
    }
  }

  private func createDeleteConfirmationDialog(id: RecordingInfo.ID, state: inout State) {
    state.alert = AlertState {
      TextState("Confirmation")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("Cancel")
      }
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

  @State var showListItems = false

  public init(store: StoreOf<RecordingListScreen>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: .grid(4)) {
          ForEachStore(store.scope(
            state: \.recordingRows,
            action: RecordingListScreen.Action.recording(id:action:)
          )) { store in
            makeRecordingRow(store: store)
          }
        }
        .padding(.grid(4))
        .onChange(of: viewStore.recordings.count) {
          showListItems = $0 > 0
        }
        .animation(.default, value: viewStore.recordings.count)
      }
      .background {
        if viewStore.recordings.isEmpty {
          EmptyStateView()
        }
      }
      .screenRadialBackground()

      .navigationDestination(isPresented: Binding(
        get: { viewStore.selection != nil },
        set: { if !$0 { viewStore.send(.recordingSelected(id: nil)) } }
      )) {
        IfLetStore(store.scope(
          state: \.selection?.value,
          action: RecordingListScreen.Action.details
        )) {
          RecordingDetailsView(store: $0)
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
    }
    .overlay {
      if viewStore.isImportingFiles {
        Color.black.opacity(0.5).overlay(ProgressView())
      }
    }
    .alert(store.scope(state: \.alert), dismiss: .binding(.set(\.$alert, nil)))
    .navigationViewStyle(.stack)
    .task {
      viewStore.send(.readStoredRecordings)
    }
    .onAppear {
      viewStore.send(.readStoredRecordings)
    }
    .enableInjection()
  }
}

extension RecordingListScreenView {
  @ViewBuilder
  private func makeRecordingRow(store: Store<RecordingListScreen.Row, RecordingCard.Action>) -> some View {
    let index = ViewStore(store).index
    let recordingId = ViewStore(store).id
    let cardStore = store.scope(state: \.card)

    HStack(spacing: .grid(4)) {
      if viewStore.editMode.isEditing {
        Button { viewStore.send(.delete(id: recordingId)) } label: {
          Image(systemName: "multiply.circle.fill")
        }.iconButtonStyle()
      }

      Button { viewStore.send(.recordingSelected(id: recordingId)) } label: {
        RecordingCardView(store: cardStore)
          .offset(y: showListItems ? 0 : 500)
          .opacity(showListItems ? 1 : 0)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.75)
              .delay(Double(index) * 0.15),
            value: showListItems
          )
      }.cardButtonStyle()
    }
    .animation(.gentleBounce(), value: viewStore.editMode.isEditing)
  }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
  @ObserveInjection var inject

  var body: some View {
    VStack(spacing: .grid(4)) {
      WithInlineState(initialValue: 0) { state in
        Image(systemName: "waveform.path.ecg")
          .font(.system(size: 100))
          .foregroundColor(.DS.Text.accent)
          .shadow(color: .DS.Text.accent.opacity(state.wrappedValue), radius: 20 * state.wrappedValue, x: 0, y: 0)
          .animateForever(using: .easeInOut(duration: 2), autoreverses: true) {
            state.wrappedValue = 1
          }
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
