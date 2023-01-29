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
    var isLoading = true
  }

  enum Action: Equatable {
    case task
    case setModels([VoiceModel])
    case modelSelected(VoiceModel)
    case setSelectedModel(VoiceModel)
    case downloadModel(VoiceModel)
    case modelUpdated(VoiceModel)
    case loadError(String)
  }

  private var modelDownload: ModelDownloadClient { .live }
  @Dependency(\.transcriber) var transcriber

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
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
        state.isLoading = true
        return .task {
          do {
            try await transcriber.loadModel(model.type.localURL)
            return .setSelectedModel(model)
          } catch {
            log(error)
            return .loadError(error.localizedDescription)
          }
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

      case let .modelUpdated(model):
        return .task { [models = state.models] in
          .setModels(models.map { m in
            m.id == model.id ? model : m
          })
        }

      case let .loadError(error):
        state.isLoading = false
        log(error)
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
    VStack(spacing: .grid(2)) {
      Text(
        "Whisper is an automatic speech recognition (ASR) model developed by OpenAI. It uses deep learning techniques to transcribe spoken language into text. It is designed to be more accurate and efficient than traditional ASR models.\n\nThere are several different Whisper models available, each with different capabilities. The main difference between them is the size of the model, which affects the accuracy and efficiency of the transcription."
      )
      .font(.DS.footnote)
      .foregroundColor(.DS.Text.subdued)
      .multilineTextAlignment(.leading)
      .padding(.horizontal, .grid(2))

      ForEach(viewStore.models) { model in
        HStack {
          Text(model.name)
          Text(model.type.sizeLabel)
            .foregroundColor(Color.DS.Text.subdued)
          Spacer()
          if model.isDownloaded {
            Image(systemName: model == viewStore.selectedModel ? "checkmark.circle.fill" : "circle")
          } else if model.isDownloading {
            ProgressView(value: model.downloadProgress)
          } else {
            Text("Download")
              .padding(.grid(2))
              .background(Color.DS.Background.accent)
              .cornerRadius(.grid(2))
          }
        }
        .foregroundColor(model == viewStore.selectedModel ? .green : .white)
        .padding(.horizontal, .grid(2))
        .frame(height: 50)
        .background {
          RoundedRectangle(cornerRadius: .grid(4))
            .fill(Color.DS.Background.tertiary)
        }
        .onTapGesture { viewStore.send(.modelSelected(model)) }
      }
    }
    .padding(.grid(2))
    .background {
      RoundedRectangle(cornerRadius: .grid(4))
        .fill(Color.DS.Background.secondary)
    }
    .overlay {
      ZStack {
        if viewStore.isLoading {
          Color.DS.Shadow.primary.ignoresSafeArea()
          ProgressView()
        }
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
  }
}
