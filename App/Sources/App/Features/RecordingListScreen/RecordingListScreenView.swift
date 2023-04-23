import AppDevUtils
import Combine
import ComposableArchitecture
import Dependencies
import Inject
import SwiftUI

// MARK: - RecordingListScreen

public struct RecordingListScreen: ReducerProtocol {
  public struct State: Equatable {
    var recordingCards: IdentifiedArrayOf<RecordingCard.State> = []
    var selection: Identified<RecordingInfo.ID, RecordingDetails.State>?

    @BindingState var editMode: EditMode = .inactive
    @BindingState var isImportingFiles = false
    @BindingState var alert: AlertState<Action>?
  }

  public enum Action: BindableAction, Equatable {
    case task
    case binding(BindingAction<State>)
    case receivedRecordings([RecordingEnvelop])
    case recordingCard(id: RecordingCard.State.ID, action: RecordingCard.Action)
    case delete(id: RecordingInfo.ID)
    case addFileRecordings(urls: [URL])
    case failedToAddRecordings(error: EquatableErrorWrapper)
    case deleteDialogConfirmed(id: RecordingInfo.ID)
    case details(action: RecordingDetails.Action)
    case recordingSelected(id: RecordingInfo.ID?)
  }

  @Dependency(\.storage) var storage: StorageClient
  @Dependency(\.fileImport) var fileImport: FileImportClient
  @Dependency(\.recordingsStream) var recordingsStream: @Sendable ()
    -> AnyPublisher<[RecordingEnvelop], Never>

  struct SavingRecordingsID: Hashable {}
  struct StreamID: Hashable {}

  public var body: some ReducerProtocol<State, Action> {
    CombineReducers {
      BindingReducer<State, Action>()

      Reduce<State, Action> { state, action in
        switch action {
        case .task:
          return .run { send in
            for await envelops in recordingsStream().values {
              await send(.receivedRecordings(envelops))
            }
          }.cancellable(id: StreamID(), cancelInFlight: true)

        case let .receivedRecordings(envelops):
          state.recordingCards = envelops.map { envelop in
            guard var card = state.recordingCards[id: envelop.id] else {
              return RecordingCard.State(recordingEnvelop: envelop)
            }
            card.recordingEnvelop = envelop
            return card
          }.identifiedArray

          state.selection = state.selection.flatMap { selection -> Identified<RecordingInfo.ID, RecordingDetails.State>? in
            guard let card = state.recordingCards.first(where: { $0.id == selection.id }) else {
              return nil
            }
            return Identified(RecordingDetails.State(recordingCard: card), id: selection.id)
          }

          return .none

        case .binding:
          return .none

        case .recordingCard:
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
          }.animation(.gentleBounce())

        case let .failedToAddRecordings(error):
          log.error(error.error)
          state.alert = .error(error)
          return .none

        case let .deleteDialogConfirmed(id):
          if state.selection?.id == id {
            state.selection = nil
          }

          do {
            try storage.delete(id)
          } catch {
            log.error(error)
            state.alert = .error(error)
          }
          return .none

        case .details:
          return .none

        case let .recordingSelected(id):
          guard let id else {
            state.selection = nil
            return .none
          }

          state.selection = state.recordingCards.first(where: { $0.id == id }).map { card in
            Identified(RecordingDetails.State(recordingCard: card), id: id)
          }
          return .none
        }
      }
    }
    .forEach(\.recordingCards, action: /Action.recordingCard(id:action:)) {
      RecordingCard()
    }
    .ifLet(\.selection, action: /Action.details) {
      Scope(state: \Identified<RecordingInfo.ID, RecordingDetails.State>.value, action: /.self) {
        RecordingDetails()
      }
    }

    // // Sync changes between detailed screen and current list screen
    // .onChange(of: \.selection) { selection, state, _ -> EffectTask<Action> in
    //   guard let selection else { return .none }
    //
    //   state.recordingCards = state.recordingCards.map { row in
    //     row.id == selection.id ? Row(index: row.index, card: selection.value.recordingCard) : row
    //   }.identified()
    //
    //   return .none
    // }

    // // Make sure all changes are saved to disk
    // .onChange(of: \.recordingCards) { recordingCards, _, action -> EffectTask<Action> in
    //   if case .setRecordings = action {
    //   } else {
    //     storage.write(recordingCards.map(\.card.recordingEnvelop).identifiedArray)
    //   }
    //   return .none
    // }
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

@MainActor
public struct RecordingListScreenView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordingListScreen>
  @ObservedObject var viewStore: ViewStoreOf<RecordingListScreen>

  @State var showListItems = false

  public init(store: StoreOf<RecordingListScreen>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: .grid(4)) {
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
          // ForEachStore(store.scope(
          //   state: \.recordingCards,
          //   action: RecordingListScreen.Action.recording(id:action:)
          // )) { store in
          //   makeRecordingCard(store: store)
          // }
        }
        .padding(.grid(4))
        .onChange(of: viewStore.recordingCards.count) {
          showListItems = $0 > 0
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.default, value: viewStore.recordingCards.count)
      }
      .background {
        if viewStore.recordingCards.isEmpty {
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
    .task { await viewStore.send(.task).finish() }
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
        .animateForever(using: .easeInOut(duration: 2), autoreverses: true) {
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
