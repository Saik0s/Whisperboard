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
    case deleteDialogConfirmed(id: RecordingInfo.ID)
    case details(action: RecordingDetails.Action)
    case recordingSelected(id: RecordingInfo.ID?)
  }

  @Dependency(\.storage) var storage: StorageClient

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

        case let .delete(indexSet):
          state.alert = AlertState {
            TextState("Confirmation")
          } actions: {
            ButtonState(role: .cancel) {
              TextState("Cancel")
            }
            ButtonState(action: .deleteDialogConfirmed(id: indexSet)) {
              TextState("Delete")
            }
          } message: {
            TextState("Are you sure you want to delete this recording?")
          }
          return .none

        case .plusButtonTapped:
          return .none

        case let .addFileRecordings(urls):
          let recordings = urls.map { url -> RecordingInfo in
            let fileName = url.lastPathComponent
            let newURL = storage.audioFileURLWithName(fileName)
            do {
              try FileManager.default.copyItem(at: url, to: newURL)
            } catch {
              log(error)
            }
            let recordingInfo = RecordingInfo(fileName: fileName, date: Date(), duration: 0)
            return recordingInfo
          }
          state.recordings.append(contentsOf: recordings.map { RecordingCard.State(recordingInfo: $0) })
          return .none

        case let .deleteDialogConfirmed(id):
          guard let recording = state.recordings.first(where: { $0.id == id }) else {
            return .none
          }

          state.recordings.removeAll(where: { $0.id == id })
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
    NavigationView {
      VStack(alignment: .leading, spacing: 0) {
        // HStack {
        //   Image(systemName: "magnifyingglass")
        //   TextField(
        //     "Search for recording",
        //     text: viewStore.binding(\.$searchQuery)
        //   )
        //   .textFieldStyle(.roundedBorder)
        //   .autocapitalization(.none)
        //   .disableAutocorrection(true)
        // }
        // .padding(.horizontal, 16)

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
      .navigationTitle("Recordings")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarItems(
        leading: EditButton().tint(.DS.Text.base),
        trailing: FilePicker(types: [.wav], allowMultiple: true) { urls in
          viewStore.send(.addFileRecordings(urls: urls))
        } label: {
          Image(systemName: "plus")
            .tint(.DS.Text.base)
        }
      )
      .environment(
        \.editMode,
        viewStore.binding(\.$editMode)
      )
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

      NavigationLink(
        destination: IfLetStore(
          self.store.scope(
            state: \.selection?.value,
            action: RecordingListScreen.Action.details
          )
        ) {
          RecordingDetailsView(store: $0)
            .navigationBarItems(
              trailing: HStack(spacing: .grid(4)) {
                Button { viewStore.send(.delete(id: recording.id)) } label: {
                  Image(systemName: "trash.circle")
                }
              }
            )
        },
        tag: recording.id,
        selection: viewStore.binding(
          get: \.selection?.id,
          send: RecordingListScreen.Action.recordingSelected(id:)
        )
      ) {
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
