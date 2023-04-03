import AppDevUtils
import ComposableArchitecture
import Foundation
import Setting
import SwiftUI

// MARK: - ModelSelector

struct ModelSelector: ReducerProtocol {
  struct State: Equatable {
    var modelRows: IdentifiedArrayOf<ModelRow.State> = []
    @BindingState var alert: AlertState<Action>?

    var selectedModel: VoiceModelType {
      modelRows.first(where: \.isSelected)?.model.modelType ?? .default
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case onAppear
    case modelRow(id: VoiceModel.ID, action: ModelRow.Action)
  }

  @Dependency(\.modelDownload) var modelDownload: ModelDownloadClient
  @Dependency(\.transcriber) var transcriber: TranscriberClient

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .onAppear:
        reloadSelectedModel(state: &state)
        return .none

      case let .modelRow(_, action: .loadError(message)):
        state.alert = .error(message: message)
        return .none

      case .modelRow(_, action: .selectModelTapped):
        reloadSelectedModel(state: &state)
        return .none

      case .modelRow:
        return .none

      case .binding:
        return .none
      }
    }
    .forEach(\.modelRows, action: /Action.modelRow) {
      ModelRow()
    }
  }

  private func reloadSelectedModel(state: inout State) {
    let selected = transcriber.getSelectedModel()
    state.modelRows = modelDownload.getModels().map { model in
      ModelRow.State(model: model, isSelected: model.modelType == selected)
    }.identifiedArray
  }
}
