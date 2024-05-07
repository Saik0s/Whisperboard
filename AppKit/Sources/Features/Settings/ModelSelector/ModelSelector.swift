import ComposableArchitecture
import Foundation
import Inject
import SwiftUI

// MARK: - ModelSelector

@Reducer
struct ModelSelector {
  @ObservableState
  struct State: Equatable {
    var modelRows: IdentifiedArrayOf<ModelRow.State> = []

    @Presents var alert: AlertState<Action.Alert>?

    @Shared var selectedModel: VoiceModelType

    init(selectedModel: Shared<VoiceModelType>) {
      _selectedModel = selectedModel
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case modelRow(IdentifiedActionOf<ModelRow>)
    case alert(PresentationAction<Alert>)

    case reloadModels

    enum Alert: Equatable {}
  }

  @Dependency(\.modelDownload) var modelDownload: ModelDownloadClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce<State, Action> { state, action in
      switch action {
      case .reloadModels:
        reloadModels(state: &state)
        return .none

      case let .modelRow(.element(_, action: .loadError(message))):
        state.alert = .error(message: message)
        return .none

      case .modelRow(.element(_, action: .didRemoveModel)):
        reloadModels(state: &state)
        return .none

      case let .modelRow(.element(id, action: .selectModelTapped)):
        guard let modelRow = state.modelRows[id: id] else { return .none }
        state.selectedModel = modelRow.model.modelType
        reloadModels(state: &state)
        return .none

      case .modelRow:
        return .none

      case .binding:
        return .none

      case .alert:
        return .none
      }
    }
    .forEach(\.modelRows, action: \.modelRow) {
      ModelRow()
    }
    .ifLet(\.$alert, action: \.alert)
  }

  private func reloadModels(state: inout State) {
    state.modelRows = modelDownload.getModels().map { ModelRow.State(model: $0) }.identifiedArray
  }
}

// MARK: - ModelSelectorView

struct ModelSelectorView: View {
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>

  var body: some View {
    WithPerceptionTracking {
      Form {
        Section {
          ForEach(store.scope(state: \.modelRows, action: \.modelRow)) { modelRowStore in
            WithPerceptionTracking {
              ModelRowView(store: modelRowStore, isSelected: store.selectedModel == modelRowStore.model.modelType)
            }
          }
          .listRowBackground(Color.DS.Background.secondary)
        }
      }
      .onAppear { store.send(.reloadModels) }
      .alert($store.scope(state: \.alert, action: \.alert))
    }
    .enableInjection()
  }

  @ObserveInjection var inject
}
