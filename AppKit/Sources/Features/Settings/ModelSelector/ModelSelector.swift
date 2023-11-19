import ComposableArchitecture
import Foundation
import Inject
import SwiftUI

// MARK: - ModelSelector

struct ModelSelector: ReducerProtocol {
  struct State: Equatable {
    var modelRows: IdentifiedArrayOf<ModelRow.State> = []

    @PresentationState var alert: AlertState<Action.Alert>?

    var selectedModel: VoiceModelType {
      modelRows.first(where: \.isSelected)?.model.modelType ?? .default
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case reloadSelectedModel
    case modelRow(id: VoiceModel.ID, action: ModelRow.Action)
    case alert(PresentationAction<Alert>)

    enum Alert: Equatable {}
  }

  @Dependency(\.modelDownload) var modelDownload: ModelDownloadClient
  @Dependency(\.settings) var settings: SettingsClient

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Reduce<State, Action> { state, action in
      switch action {
      case .reloadSelectedModel:
        reloadSelectedModel(state: &state)
        return .none

      case let .modelRow(_, action: .loadError(message)):
        state.alert = .error(message: message)
        return .none

      case .modelRow(_, action: .didRemoveModel):
        reloadSelectedModel(state: &state)
        return .none

      case .modelRow(_, action: .selectModelTapped):
        reloadSelectedModel(state: &state)
        return .none

      case .modelRow:
        return .none

      case .binding:
        return .none

      case .alert:
        return .none
      }
    }
    .forEach(\.modelRows, action: /Action.modelRow) {
      ModelRow()
    }
    .ifLet(\.$alert, action: /Action.alert)
  }

  private func reloadSelectedModel(state: inout State) {
    let selected = settings.getSettings().selectedModel
    state.modelRows = modelDownload.getModels().map { model in
      ModelRow.State(model: model, isSelected: model.modelType == selected)
    }.identifiedArray
  }
}

// MARK: - ModelSelectorView

struct ModelSelectorView: View {
  let store: Store<ModelSelector.State, ModelSelector.Action>

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Form {
        Section {
          ForEachStore(store.scope(state: \.modelRows, action: ModelSelector.Action.modelRow)) { modelRowStore in
            ModelRowView(store: modelRowStore)
          }
          .listRowBackground(Color.DS.Background.secondary)
        }
      }
      .onAppear { viewStore.send(.reloadSelectedModel) }
      .alert(store: store.scope(state: \.$alert, action: { .alert($0) }))
    }
    .enableInjection()
  }

  @ObserveInjection var inject
}
