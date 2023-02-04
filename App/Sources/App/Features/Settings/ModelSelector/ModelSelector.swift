import AppDevUtils
import ComposableArchitecture
import Foundation
import SwiftUI

extension UserDefaults {
  var selectedModelName: String? {
    get { string(forKey: #function) }
    set { set(newValue, forKey: #function) }
  }
}

// MARK: - ModelSelector

struct ModelSelector: ReducerProtocol {
  struct State: Equatable {
    var models: [VoiceModel] = []
    var selectedModel: VoiceModel?
    var isLoading = false
    var alert: AlertState<Action>?
  }

  enum Action: Equatable {
    case task
    case setModels([VoiceModel])
    case modelSelected(VoiceModel)
    case setSelectedModel(VoiceModel)
    case downloadModel(VoiceModel)
    case modelUpdated(VoiceModel)
    case deleteModel(VoiceModel)
    case loadError(String)
    case alertDismissed
  }

  private var modelDownload: ModelDownloadClient { .live }
  @Dependency(\.transcriber) var transcriber

  struct CancelDownloadID: Hashable {}

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        return .run { send in
          let models = VoiceModelType.allCases
            .map {
              VoiceModel(
                type: $0,
                downloadProgress: FileManager.default.fileExists(atPath: $0.localURL.path) ? 1 : 0
              )
            }
          await send(.setModels(models))
          if let selectedModelName = UserDefaults.standard.selectedModelName,
             let selectedModel = models.first(where: { $0.name == selectedModelName }), selectedModel.isDownloaded {
            await send(.modelSelected(selectedModel))
          } else if let model = models.first(where: { $0.isDownloaded }) {
            await send(.modelSelected(model))
          }
        }

      case let .setModels(models):
        state.models = models
        return .none

      case let .modelSelected(model):
        guard state.selectedModel != model else { return .none }

        guard model.isDownloaded else {
          return .task { .downloadModel(model) }
        }

        transcriber.unloadModel()

        state.isLoading = true
        return .task {
          .setSelectedModel(model)
        }

      case let .setSelectedModel(model):
        state.isLoading = false
        state.selectedModel = model
        UserDefaults.standard.selectedModelName = model.name
        return .none

      case let .downloadModel(model):
        return .run { send in
          await send(.modelUpdated(model.with {
            $0.isDownloading = true
          }))
          for await downloadState in await modelDownload.downloadModel(model) {
            switch downloadState {
            case let .inProgress(progress):
              await send(.modelUpdated(model.with {
                $0.downloadProgress = progress
                $0.isDownloading = true
              }))
            case let .success(fileURL):
              log(fileURL)
              await send(.modelUpdated(model.with {
                $0.downloadProgress = 1
                $0.isDownloading = false
              }))
            case let .failure(error):
              log(error)
              await send(.modelUpdated(model.with {
                $0.downloadProgress = 0
                $0.isDownloading = false
              }))
            }
          }
        }
        .animation()
        .cancellable(id: CancelDownloadID(), cancelInFlight: true)

      case let .modelUpdated(model):
        return .task { [models = state.models] in
          .setModels(models.map { m in
            m.id == model.id ? model : m
          })
        }

      case let .deleteModel(model):
        return .run { send in
          await send(.modelUpdated(model.with {
            $0.downloadProgress = 0
            $0.isDownloading = false
          }))
          try? FileManager.default.removeItem(at: model.type.localURL)
        }
      case let .loadError(error):
        state.isLoading = false
        log(error)
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
    VStack(spacing: .grid(4)) {
      Text(
        "Whisper is an automatic speech recognition (ASR) model developed by OpenAI. It uses deep learning techniques to transcribe spoken language into text. It is designed to be more accurate and efficient than traditional ASR models.\n\nThere are several different Whisper models available, each with different capabilities. The main difference between them is the size of the model, which affects the accuracy and efficiency of the transcription."
      )
      .font(.DS.footnote)
      .foregroundColor(.DS.Text.subdued)
      .multilineTextAlignment(.leading)

      modelList()
    }
    .alert(store.scope(state: \.alert), dismiss: .alertDismissed)
  }

  private func modelList() -> some View {
    VStack(spacing: .grid(4)) {
      ForEach(viewStore.models) { model in
        HStack(spacing: .grid(4)) {
          Image(systemName: model == viewStore.selectedModel ? "checkmark.circle.fill" : "circle")
            .font(.DS.headlineL)
            .opacity(model.isDownloaded ? 1 : 0.3)

          VStack(alignment: .leading, spacing: .grid(2)) {
            Text(model.readableName)
              .font(.DS.headlineM)
              .foregroundColor(Color.DS.Text.base)
            Text(model.type.sizeLabel)
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
        .padding(.horizontal, .grid(2))
        .frame(height: 50)
        .onTapGesture { viewStore.send(.modelSelected(model)) }

        if model != viewStore.models.last {
          Divider()
        }
      }
    }
    .padding(.grid(4))
    .background(Color.DS.Background.secondary)
    .overlay {
      ZStack {
        if viewStore.isLoading {
          Color.DS.Shadow.primary.ignoresSafeArea()
          ProgressView()
        }
      }
    }
    .continuousCornerRadius(.grid(6))
    .shadow(style: .card)
  }

  func contextMenu(for model: VoiceModel) -> ContextMenu<TupleView<(Button<Text>, Button<Text>)>> {
    ContextMenu {
      Button(action: { viewStore.send(.modelSelected(model)) }) {
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
            VoiceModel(type: .base),
            VoiceModel(type: .baseEN),
          ],
          selectedModel: nil
        ),
        reducer: ModelSelector()
      )
    )
    .previewPreset()
  }
}
