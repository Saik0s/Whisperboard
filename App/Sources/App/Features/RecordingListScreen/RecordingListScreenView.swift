import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingListScreen

public struct RecordingListScreen: ReducerProtocol {
  public struct State: Equatable {
    var alert: AlertState<Action>?
    var recordings: IdentifiedArrayOf<RecordingCard.State> = []
    @BindingState var searchQuery = ""
    @BindingState var editMode: EditMode = .inactive
    var selection: Identified<RecordingInfo.ID, RecordingDetails.State>?
    @BindingState var isImportingFiles = false
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case alertDismissed
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
    CombineReducers {
      BindingReducer<State, Action>()

      Reduce<State, Action> { state, action in
        switch action {
        case .binding:
          return .none

        case .alertDismissed:
          state.alert = nil
          return .none

        case .readStoredRecordings:
          return .task {
            await .setRecordings(TaskResult { try await storage.read() })
          }

        case let .setRecordings(.success(recordings)):
          state.recordings = recordings.map { info in
            RecordingCard.State(recordingInfo: info)
          }
          .identifiedArray
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
          errorAlert(error: error.error, state: &state)
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
      ButtonState(action: .deleteDialogConfirmed(id: id)) {
        TextState("Delete")
      }
    } message: {
      TextState("Are you sure you want to delete this recording?")
    }
  }

  private func errorAlert(error: Error, state: inout State) {
    state.alert = AlertState(title: TextState("Something went wrong"), message: TextState(error.localizedDescription))
  }
}

// MARK: - RecordingListScreenView

public struct RecordingListScreenView: View {
  enum ViewMode: Hashable { case audio, text }

  @Namespace var animation

  @ObserveInjection var inject

  let store: StoreOf<RecordingListScreen>
  @ObservedObject var viewStore: ViewStoreOf<RecordingListScreen>

  @State var showListItems = false
  @State var viewMode: ViewMode = .audio

  public init(store: StoreOf<RecordingListScreen>) {
    self.store = store
    viewStore = ViewStore(store)

    UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.DS.Background.accent)
    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
    UISegmentedControl.appearance().backgroundColor = .clear
    UISegmentedControl.appearance().setBackgroundImage(nil, for: .normal, barMetrics: .default)
  }

  public var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 0) {
        Picker(selection: $viewMode, label: Text("Display style")) {
          Image(systemName: "waveform.path.ecg")
            .tag(ViewMode.audio)
          Image(systemName: "doc.text")
            .tag(ViewMode.text)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, .grid(4))
        .padding(.vertical, .grid(6))

        ScrollView {
          LazyVStack(spacing: .grid(4)) {
            ForEachWithIndex(viewStore.recordings) { index, recording in
              RecordingRow(recording: recording, index: index)
                .tag(recording.id)
            }
          }
          .padding(.grid(4))
          .onChange(of: viewStore.recordings.count) {
            showListItems = $0 > 0
          }
          .animation(.default, value: viewStore.recordings.count)
        }
      }
      .screenRadialBackground()

      .navigationDestination(
        isPresented: Binding(
          get: { viewStore.selection != nil },
          set: { if !$0 { viewStore.send(.recordingSelected(id: nil)) } }
        )
      ) {
        IfLetStore(
          self.store.scope(
            state: \.selection?.value,
            action: RecordingListScreen.Action.details
          )
        ) {
          RecordingDetailsView(store: $0)
        }
      }
      .navigationTitle("Recordings")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarItems(
        leading: EditButton().tint(.DS.Text.base),
        trailing: FilePicker(types: [.wav, .mp3, .mpeg4Audio], allowMultiple: true) { urls in
          viewStore.send(.addFileRecordings(urls: urls))
        } label: {
          Image(systemName: "doc.badge.plus")
            .tint(.DS.Text.base)
        }
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
    .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
    .navigationViewStyle(.stack)
    .task {
      viewStore.send(.readStoredRecordings)
    }
    .enableInjection()
  }
}

extension RecordingListScreenView {
  private func RecordingRow(recording: RecordingCard.State, index: Int) -> some View {
    HStack(spacing: .grid(2)) {
      if viewStore.editMode.isEditing {
        Button {
          viewStore.send(.delete(id: recording.id))
        } label: {
          Image(systemName: "multiply.circle.fill")
            .foregroundColor(.DS.Text.error)
        }
      }

      Button { viewStore.send(.recordingSelected(id: recording.id)) } label: {
        IfLetStore(
          self.store.scope(
            state: { $0.recordings.first(where: { $0.id == recording.id }) },
            action: { RecordingListScreen.Action.recording(id: recording.id, action: $0) }
          )
        ) { cardStore in
          ZStack {
            if viewMode == .audio {
              RecordingCardView(store: cardStore)
            } else {
              RecordingTextView(store: cardStore)
            }
          }
        }
        .offset(y: showListItems ? 0 : 500)
        .opacity(showListItems ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(Double(index) * 0.15),
                   value: showListItems)
        .animation(.gentleBounce(), value: viewMode)
      }
    }
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
