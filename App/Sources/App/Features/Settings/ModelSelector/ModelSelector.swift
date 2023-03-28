import AppDevUtils
import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - ModelSelector

struct ModelSelector: ReducerProtocol {
  struct State: Equatable {
    var models: [VoiceModel] = []
    var selectedModelType: VoiceModelType = .default
    var alert: AlertState<Action>?
  }

  enum Action: Equatable {
    case task
    case setModels([VoiceModel])
    case modelRowTapped(VoiceModel)
    case setSelectedModelType(VoiceModelType)
    case downloadModel(VoiceModel)
    case modelUpdated(VoiceModel)
    case deleteModel(VoiceModel)
    case loadError(String)
    case alertDismissed
  }

  @Dependency(\.modelDownload) var modelDownload: ModelDownloadClient
  @Dependency(\.transcriber) var transcriber: TranscriberClient

  struct CancelDownloadID: Hashable {}

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        return .run { send in
          await send(.setModels(modelDownload.getModels()))
          await send(.setSelectedModelType(transcriber.getSelectedModel()))
        }

      case let .setModels(models):
        state.models = models
        return .none

      case let .modelRowTapped(model):
        guard state.selectedModelType != model.modelType else {
          return .none
        }

        guard model.isDownloaded else {
          return .task { .downloadModel(model) }
        }

        return .task {
          .setSelectedModelType(model.modelType)
        }

      case let .setSelectedModelType(modelType):
        state.selectedModelType = modelType
        return .fireAndForget {
          transcriber.selectModel(modelType)
        }

      case let .downloadModel(model):
        return .run { send in
          await send(.modelUpdated(model.with {
            $0.isDownloading = true
          }))

          for await downloadState in await modelDownload.downloadModel(model) {
            await send(.modelUpdated(model.with {
              $0.downloadProgress = downloadState.progress
              $0.isDownloading = downloadState.isDownloading
            }))

            if let error = downloadState.error {
              log.error(error)
              await send(.loadError(error.localizedDescription))
            }

            if downloadState.isDownloaded {
              await send(.setSelectedModelType(model.modelType))
            }
          }
        }
        .animation()
        .cancellable(id: CancelDownloadID(), cancelInFlight: true)

      case let .modelUpdated(model):
        state.models = state.models.map { m in
          m.id == model.id ? model : m
        }
        return .none

      case let .deleteModel(model):
        return .run { send in
          await send(.modelUpdated(model.with {
            $0.downloadProgress = 0
            $0.isDownloading = false
          }))
          try? FileManager.default.removeItem(at: model.modelType.localURL)
        }

      case let .loadError(error):
        state.alert = .init(
          title: TextState("Error"),
          message: TextState(error),
          dismissButton: .default(TextState("OK"), action: .send(Action.alertDismissed, animation: .default))
        )
        return .none

      case .alertDismissed:
        state.alert = nil
        return .none
      }
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
      // .screenRadialBackground()
      .enableInjection()
  }

  private func modelList() -> some View {
    Form {
      Section {
        Text(
          "Whisper is an automatic speech recognition (ASR) model developed by OpenAI. It uses deep learning techniques to transcribe spoken language into text. It is designed to be more accurate and efficient than traditional ASR models.\n\nThere are several different Whisper models available, each with different capabilities. The main difference between them is the size of the model, which affects the accuracy and efficiency of the transcription."
        )
        .font(.DS.footnote)
        .foregroundColor(.DS.Text.subdued)
        .multilineTextAlignment(.leading)
        .listRowBackground(Color.DS.Background.secondary)

        ForEach(viewStore.models) { model in
          modelRow(for: model)
            .frame(height: 40)
            .contentShape(Rectangle())
            .onTapGesture { viewStore.send(.modelRowTapped(model)) }
            .contextMenu(model.isDownloaded && model.modelType != .tiny ? contextMenu(for: model) : nil)
        }
        .listRowBackground(Color.DS.Background.secondary)
      } header: {
        Text("Select transcription model")
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .shadow(style: .card)
  }

  private func modelRow(for model: VoiceModel) -> some View {
    HStack(spacing: .grid(4)) {
      Image(systemName: model.modelType == viewStore.selectedModelType ? "checkmark.circle.fill" : "circle")
        .font(.DS.headlineL)
        .opacity(model.isDownloaded ? 1 : 0.3)

      VStack(alignment: .leading, spacing: .grid(2)) {
        Text(model.modelType.readableName)
          .font(.DS.headlineM)
          .foregroundColor(Color.DS.Text.base)
        Text(model.modelType.sizeLabel)
          .font(.DS.captionS)
          .foregroundColor(Color.DS.Text.subdued)
      }

      Spacer()

      if model.isDownloading {
        ProgressView(value: model.downloadProgress)
      } else if model.isDownloaded == false {
        Text("Download")
          .padding(.grid(2))
          .background(Color.DS.Background.accentAlt)
          .cornerRadius(.grid(2))
      }
    }
    .foregroundColor(model.modelType == viewStore.selectedModelType ? Color.DS.Text.success : Color.DS.Text.base)
  }

  func contextMenu(for model: VoiceModel) -> ContextMenu<TupleView<(Button<Text>, Button<Text>)>> {
    ContextMenu {
      Button(action: { viewStore.send(.modelRowTapped(model)) }) {
        Text("Select")
      }
      Button(action: { viewStore.send(.deleteModel(model)) }) {
        Text("Delete")
      }
    }
  }
}

// MARK: - ModelSelector_Previews

struct ModelSelector_Previews: PreviewProvider {
  static var previews: some View {
    ModelSelectorView(
      store: Store(
        initialState: ModelSelector.State(
          models: [
            VoiceModel(modelType: .base),
            VoiceModel(modelType: .baseEN),
            VoiceModel(modelType: .default),
          ],
          selectedModelType: .default
        ),
        reducer: ModelSelector()
      )
    )
    .previewPreset()
  }
}
