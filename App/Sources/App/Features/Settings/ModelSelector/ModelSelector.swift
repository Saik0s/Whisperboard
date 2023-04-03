import AppDevUtils
import ComposableArchitecture
import Foundation
import Setting
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
        reloadSelectedModel(state: &state)
        return .none

      case let .modelRow(_, action: .loadError(error)):
        state.alert = .init(
          title: TextState("Error"),
          message: TextState(error),
          dismissButton: .default(TextState("OK"), action: .send(Action.alertDismissed, animation: .default))
        )
        return .none

      case .modelRow(_, action: .selectModelTapped):
        reloadSelectedModel(state: &state)
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

  private func reloadSelectedModel(state: inout State) {
    let selected = transcriber.getSelectedModel()
    state.modelRows = modelDownload.getModels().map { model in
      ModelRow.State(model: model, isSelected: model.modelType == selected)
    }.identifiedArray
  }
}

func ModelSelectorSettingPage(store: StoreOf<ModelSelector>) -> SettingPage {
  SettingPage(
    title: "Model Selector",
    backgroundColor: .DS.Background.primary,
    previewConfiguration: .init(icon: .system(icon: "square.and.arrow.down", backgroundColor: .systemPurple))
  ) {
    SettingGroup(footer: .modelSelectorFooter, backgroundColor: .DS.Background.secondary) {
      SettingCustomView(id: "models") {
        ForEachStore(store.scope(state: \.modelRows, action: ModelSelector.Action.modelRow)) { modelRowStore in
          ModelRowView(store: modelRowStore)
        }
        .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
      }
    }
  }
}

private extension String {
  static let modelSelectorFooter = """
  Whisper ASR, by OpenAI, is an advanced system that converts spoken words into written text. It's perfect for transcribing conversations or speeches.
  """
}

// MARK: - ModelSelector_Previews

struct ModelSelector_Previews: PreviewProvider {
  static var previews: some View {
    SettingStack {
      ModelSelectorSettingPage(
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
    }
    .previewPreset()
  }
}
