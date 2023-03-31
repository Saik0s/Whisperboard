import AppDevUtils
import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - ModelSelector

struct ModelSelector: ReducerProtocol {
  struct State: Equatable {
    var modelRows: IdentifiedArrayOf<ModelRow.State> = []
    var alert: AlertState<Action>?
  }

  enum Action: Equatable {
    case task
    case alertDismissed
    case modelRow(id: VoiceModel.ID, action: ModelRow.Action)
  }

  @Dependency(\.modelDownload) var modelDownload: ModelDownloadClient
  @Dependency(\.transcriber) var transcriber: TranscriberClient

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        let selected = transcriber.getSelectedModel()
        state.modelRows = modelDownload.getModels().map { model in
          ModelRow.State(model: model, isSelected: model.modelType == selected)
        }.identifiedArray
        return .none

      case let .modelRow(_, action: .loadError(error)):
        state.alert = .init(
          title: TextState("Error"),
          message: TextState(error),
          dismissButton: .default(TextState("OK"), action: .send(Action.alertDismissed, animation: .default))
        )
        return .none

      case .alertDismissed:
        state.alert = nil
        return .none

      case .modelRow:
        return .none
      }
    }
    .forEach(\.modelRows, action: /Action.modelRow) {
      ModelRow()
    }
  }
}

// MARK: - ModelSelectorView

struct ModelSelectorView: View {
  let store: StoreOf<ModelSelector>
  @ObservedObject var viewStore: ViewStoreOf<ModelSelector>

  init(store: StoreOf<ModelSelector>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    modelList()
      .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
      .enableInjection()
  }

  @ViewBuilder
  private func modelList() -> some View {

    ForEachStore(store.scope(state: \.modelRows, action: ModelSelector.Action.modelRow)) { modelRowStore in
      ModelRowView(store: modelRowStore)
    }
  }
}

// MARK: - ModelSelector_Previews

struct ModelSelector_Previews: PreviewProvider {
  static var previews: some View {
    ModelSelectorView(
      store: Store(
        initialState: ModelSelector.State(
          modelRows: [
            VoiceModel(modelType: .base),
            VoiceModel(modelType: .baseEN),
            VoiceModel(modelType: .default),
          ]
          .map { ModelRow.State(model: $0, isSelected: false) }
          .identifiedArray
        ),
        reducer: ModelSelector()
      )
    )
    .previewPreset()
  }
}
