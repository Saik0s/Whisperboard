
import ComposableArchitecture
import Foundation
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
