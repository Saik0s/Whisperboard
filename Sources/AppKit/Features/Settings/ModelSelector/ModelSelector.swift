import AudioProcessing
import Common
import ComposableArchitecture
import Foundation
import Inject
import SwiftUI

// MARK: - ModelSelector

@Reducer
struct ModelSelector {
  @ObservableState
  struct State: Equatable {
    struct LoadingProgress: Equatable {
      var id: Model.ID
      var progress: Double
    }

    var models: IdentifiedArrayOf<Model> = []
    var loadQueue: Set<Model.ID> = []
    @Shared var loadingProgress: LoadingProgress?
    @Shared(.appStorage("selectedModelID")) var selectedModelID: Model.ID? = nil

    @Presents var alert: AlertState<Action.Alert>?

    init() {
      _loadingProgress = Shared(nil)
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case downloadButtonTapped(Model.ID)
    case downloadTask(id: Model.ID, TaskResult<Void>)
    case reloadModels
    case modelsResponse(TaskResult<[Model]>)
    case cancelDownloadButtonTapped(Model.ID)
    case deleteModelButtonTapped(Model.ID)
    case selectModelButtonTapped(Model.ID)

    case alert(PresentationAction<Alert>)

    enum Alert: Equatable {}
  }

  enum CancelID: Hashable { case modelID(Model.ID) }

  @Dependency(RecordingTranscriptionStream.self) var transcriptionStream: RecordingTranscriptionStream

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .downloadButtonTapped(id):
        guard state.loadingProgress == nil else {
          if state.loadingProgress?.id != id {
            state.loadQueue.insert(id)
          }
          return .none
        }

        return loadModel(state: &state, id: id)

      case let .downloadTask(id: id, .success):
        state.loadingProgress = nil
        state.selectedModelID = id
        return loadNextInQueue(state: &state)

      case let .downloadTask(id: _, .failure(error)):
        state.loadingProgress = nil
        state.alert = .error(message: error.localizedDescription)
        return loadNextInQueue(state: &state)

      case .reloadModels:
        return fetchModels()

      case let .modelsResponse(.success(models)):
        state.models = models.identifiedArray
        return .none

      case let .modelsResponse(.failure(error)):
        state.alert = .error(message: error.localizedDescription)
        return .none

      case let .cancelDownloadButtonTapped(id):
        state.loadQueue.remove(id)
        if state.loadingProgress?.id == id {
          state.loadingProgress = nil
          return .cancel(id: CancelID.modelID(id))
        }
        return .none

      case let .deleteModelButtonTapped(id):
        if state.selectedModelID == id {
          state.selectedModelID = state.models.first { $0.isLocal }?.id
        }
        return .run { send in
          try await transcriptionStream.deleteModel(id)
          await send(.reloadModels)
        }

      case let .selectModelButtonTapped(id):
        state.selectedModelID = id
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }

  private func loadNextInQueue(state: inout State) -> Effect<Action> {
    if let id = state.loadQueue.first {
      .merge(
        loadModel(state: &state, id: id),
        fetchModels()
      )
    } else {
      fetchModels()
    }
  }

  private func loadModel(state: inout State, id: Model.ID) -> Effect<Action> {
    state.loadQueue.remove(id)
    state.loadingProgress = State.LoadingProgress(id: id, progress: 0)
    return .run { [loadingProgress = state.$loadingProgress] send in
      await send(.downloadTask(id: id, TaskResult {
        for try await progress in transcriptionStream.loadModel(id) {
          loadingProgress.wrappedValue?.progress = progress
        }
      }))
    }
    .cancellable(id: CancelID.modelID(id), cancelInFlight: true)
  }

  private func fetchModels() -> Effect<Action> {
    .run { send in
      await send(.modelsResponse(TaskResult { try await transcriptionStream.fetchModels() }))
    }
  }
}

// MARK: - ModelSelectorView

struct ModelSelectorView: View {
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>

  var body: some View {
    WithPerceptionTracking {
      NavigationView {
        List {
          ForEach(store.models) { model in
            WithPerceptionTracking {
              HStack {
                VStack(alignment: .leading) {
                  Text(model.name).font(.headline)
                  Text(model.description).font(.subheadline)
                }
                Spacer()
                DownloadButton(store: store, model: model)
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                  store.send(.deleteModelButtonTapped(model.id))
                } label: {
                  Image(systemName: "trash")
                }
                .disabled(!model.isLocal)
              }
              .contentShape(Rectangle())
              .contextMenu(model.isLocal ? contextMenuBuilder(id: model.id) : nil)
              .accessibilityElement(children: .combine)
            }
          }
        }
        .onAppear { store.send(.reloadModels) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .navigationTitle("Models")
      }
    }
    .enableInjection()
  }

  func contextMenuBuilder(id: Model.ID) -> ContextMenu<TupleView<(Button<Text>, Button<Text>)>> {
    ContextMenu {
      Button(action: { store.send(.selectModelButtonTapped(id)) }) { Text("Select") }
      Button(action: { store.send(.deleteModelButtonTapped(id)) }) { Text("Delete") }
    }
  }

  @ObserveInjection var inject
}

// MARK: - DownloadButton

struct DownloadButton: View {
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>
  let model: Model

  var body: some View {
    if !model.isLocal, store.loadingProgress?.id != model.id, !store.loadQueue.contains(model.id) {
      Button("Download") {
        store.send(.downloadButtonTapped(model.id))
      }
    } else if !model.isLocal, store.loadingProgress?.id == model.id || store.loadQueue.contains(model.id) {
      Button("Cancel") {
        store.send(.cancelDownloadButtonTapped(model.id))
      }
    } else if model.isLocal, store.selectedModelID == model.id {
      Button("Active") {
        store.send(.selectModelButtonTapped(model.id))
      }
    } else if model.isLocal, store.selectedModelID != model.id {
      Button("Select") {
        store.send(.selectModelButtonTapped(model.id))
      }
    }
  }
}
