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
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case alertDismissed
    case readStoredRecordings
    case setRecordings(TaskResult<IdentifiedArrayOf<RecordingInfo>>)
    case recording(id: RecordingCard.State.ID, action: RecordingCard.Action)
    case delete(IndexSet)
    case plusButtonTapped
  }

  @Dependency(\.storage) var storage

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
          .animation()

        case let .setRecordings(.success(recordings)):
          state.recordings = recordings.map(RecordingCard.State.init(recordingInfo:)).identifiedArray
          return .none

        case let .setRecordings(.failure(error)):
          state.alert = AlertState(title: TextState("Failed to read recordings."), message: TextState(error.localizedDescription))
          return .none

        case .recording:
          return .none

        case let .delete(indexSet):
          state.recordings.remove(atOffsets: indexSet)
          return .none

        case .plusButtonTapped:
          return .none
        }
      }
    }
    .forEach(\.recordings, action: /Action.recording(id:action:)) {
      RecordingCard()
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
  @ObserveInjection var inject

  let store: StoreOf<RecordingListScreen>
  @ObservedObject var viewStore: ViewStoreOf<RecordingListScreen>

  public init(store: StoreOf<RecordingListScreen>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  public var body: some View {
    NavigationView {
      VStack(alignment: .leading) {
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

        ScrollView {
          VStack(spacing: .grid(4)) {
            ForEachStore(
              store.scope(state: \.recordings, action: RecordingListScreen.Action.recording(id:action:))
            ) {
              RecordingCardView(store: $0)
            }
              .onDelete { viewStore.send(.delete($0)) }
          }
            .padding(.grid(4))
        }
      }
        .screenRadialBackground()
      .navigationTitle("Recordings")
      .navigationBarItems(
        trailing: HStack(spacing: .grid(4)) {
          Button { viewStore.send(.plusButtonTapped) } label: {
            Image(systemName: "plus")
          }
        }
      )
    }
    .navigationViewStyle(.stack)
    .task {
      viewStore.send(.readStoredRecordings)
    }
    .enableInjection()
  }
}

#if DEBUG
  struct RecordingListScreenView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordingListScreenView(
          store: Store(
            initialState: RecordingListScreen.State(),
            reducer: RecordingListScreen()
          )
        )
      }
    }
  }
#endif
