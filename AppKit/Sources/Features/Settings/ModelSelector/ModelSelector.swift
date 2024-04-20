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

  var body: some Reducer<State, Action> {
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
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>

  var body: some View {
    WithPerceptionTracking {
      Form {
        Section {
          ForEachStore(store.scope(state: \.modelRows, action: \.modelRow)) { modelRowStore in
            ModelRowView(store: modelRowStore)
          }
          .listRowBackground(Color.DS.Background.secondary)
        }
      }
      .onAppear { store.send(.reloadSelectedModel) }
      .alert($store.scope(state: \.alert, action: \.alert))
    }
    .enableInjection()
  }

  @ObserveInjection var inject
}
