//
// ModelSelector.swift
//

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
    List {
      ForEach(viewStore.models) { model in
        HStack {
          Text(model.name)
          Text(model.type.sizeLabel)
            .foregroundColor(Color.Palette.Text.subdued)
          Spacer()
          if model.isDownloaded {
            Image(systemName: model == viewStore.selectedModel ? "checkmark.circle.fill" : "circle")
          } else if model.isDownloading {
            ProgressView(value: model.downloadProgress)
          } else {
            Text("Download")
              .padding(.grid(2))
              .background(Color.black)
              .cornerRadius(.grid(1))
          }
        }
          .foregroundColor(model == viewStore.selectedModel ? .green : .white)
          .frame(height: 50)
          .onTapGesture { viewStore.send(.modelSelected(model)) }
          .listRowBackground(Color.Palette.Background.secondary)
      }
    }
    .listStyle(.plain)
    .background(LinearGradient.screenBackground)
    .overlay {
      ZStack {
        if viewStore.isLoading {
          Color.Palette.Shadow.primary.ignoresSafeArea()
          ProgressView()
        }
      }
    }
    .navigationBarTitle("Models")
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
