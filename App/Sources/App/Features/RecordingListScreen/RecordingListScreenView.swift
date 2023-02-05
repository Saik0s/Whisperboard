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

        case let .setRecordings(.success(recordings)):
          state.recordings = recordings.enumerated().map { offset, info in
            RecordingCard.State(recordingInfo: info, listIndex: offset)
          }.identifiedArray
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

  @State var showListItems = false

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
          LazyVStack(spacing: .grid(4)) {
            ForEachStore(
              store.scope(state: \.recordings, action: RecordingListScreen.Action.recording(id:action:))
            ) { cardStore in
              WithViewStore(cardStore) { cardViewStore in
                RecordingCardView(store: cardStore)
                  .offset(y: showListItems ? 0 : 100)
                  .opacity(showListItems ? 1 : 0)
                  .animation(
                    .easeInOut(duration: 0.3).delay(Double(cardViewStore.listIndex) * 0.3),
                    value: showListItems
                  )
              }
            }
          }
          .padding(.grid(4))
          .onChange(of: viewStore.recordings.count) {
            showListItems = $0 > 0
          }
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
    .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
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
