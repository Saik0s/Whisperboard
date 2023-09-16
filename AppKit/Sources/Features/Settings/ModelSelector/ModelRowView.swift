
import AsyncAlgorithms
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - ModelRow

struct ModelRow: ReducerProtocol {
  struct State: Equatable, Identifiable {
    var model: VoiceModel

    var isSelected: Bool

    var isRemovingModel: Bool = false

    var id: VoiceModel.ID { model.id }
  }

  enum Action: Equatable {
    case downloadModelTapped
    case selectModelTapped
    case modelUpdated(VoiceModel)
    case loadError(String)
    case deleteModelTapped
    case cancelDownloadTapped
    case didRemoveModel
  }

  @Dependency(\.modelDownload) var modelDownload: ModelDownloadClient
  @Dependency(\.settings) var settings: SettingsClient

  struct CancelDownloadID: Hashable {}

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .downloadModelTapped:
        guard !state.model.isDownloading else { return .none }
        state.model.isDownloading = true

        return .run { [modelType = state.model.modelType] send in
          var lastProgressUpdate = Date()
          for try await downloadState in await modelDownload.downloadModel(modelType) {
            switch downloadState {
            case let .inProgress(progress):
              let now = Date()
              if now.timeIntervalSince(lastProgressUpdate) > 0.1 {
                lastProgressUpdate = now
                await send(.modelUpdated(VoiceModel(modelType: modelType, downloadProgress: progress, isDownloading: true)))
              }
            case .success:
              await send(.modelUpdated(VoiceModel(modelType: modelType, downloadProgress: 1, isDownloading: false)))
              await send(.selectModelTapped)
            case let .failure(error):
              await send(.loadError(error.localizedDescription))
            }
          }
        } catch: { error, send in
          await send(.loadError(error.localizedDescription))
        }.cancellable(id: CancelDownloadID(), cancelInFlight: true)

      case .selectModelTapped:
        guard state.isSelected == false else { return .none }
        state.isSelected = true
        return .run { [state] _ in
          try await settings.setValue(state.model.modelType, forKey: \.selectedModel)
        }

      case let .modelUpdated(model):
        state.model = model
        return .none

      case .deleteModelTapped:
        guard state.model.isDownloaded else { return .none }

        state.isRemovingModel = true
        return .run { [modelType = state.model.modelType] send in
          modelDownload.deleteModel(modelType)
          await send(.didRemoveModel)
        }

      case .didRemoveModel:
        state.isRemovingModel = false
        return .none

      case let .loadError(error):
        log.error(error)
        state.model.isDownloading = false
        return .none

      case .cancelDownloadTapped:
        state.model.isDownloading = false
        return .cancel(id: CancelDownloadID())
      }
    }
  }
}

// MARK: - ModelRowView

struct ModelRowView: View {
  @ObserveInjection var inject

  let store: StoreOf<ModelRow>

  @ObservedObject var viewStore: ViewStoreOf<ModelRow>

  init(store: StoreOf<ModelRow>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  var body: some View {
    VStack(spacing: .grid(2)) {
      HStack(spacing: .grid(2)) {
        VStack(alignment: .leading, spacing: .grid(1)) {
          HStack(alignment: .bottom, spacing: .grid(1)) {
            Text(viewStore.model.modelType.readableName)
              .font(.DS.headlineM)
              .foregroundColor(Color.DS.Text.base)

            Text(viewStore.model.modelType.sizeLabel)
              .font(.DS.captionM)
              .foregroundColor(Color.DS.Text.subdued)
          }

          Text(viewStore.model.modelType.modelDescription)
            .font(.DS.bodyM)
            .foregroundColor(Color.DS.Text.subdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if viewStore.isRemovingModel {
          ProgressView()
        } else if viewStore.model.isDownloading {
          Button("Cancel") { viewStore.send(.cancelDownloadTapped) }
            .tertiaryButtonStyle()
        } else if viewStore.model.isDownloaded == false {
          Button("Download") { viewStore.send(.downloadModelTapped) }
            .secondaryButtonStyle()
        } else {
          Button("Active") { viewStore.send(.selectModelTapped) }
            .activeButtonStyle(isActive: viewStore.isSelected)
        }
      }

      if viewStore.model.isDownloading {
        ProgressView(value: viewStore.model.downloadProgress)
      }
    }
    .foregroundColor(viewStore.isSelected ? Color.DS.Text.success : Color.DS.Text.base)
    .contentShape(Rectangle())
    .onTapGesture { viewStore.send(.selectModelTapped) }
    .contextMenu(viewStore.model.isDownloaded && viewStore.model.modelType != .tiny ? contextMenuBuilder() : nil)
    .enableInjection()
  }

  func contextMenuBuilder() -> ContextMenu<TupleView<(Button<Text>, Button<Text>)>> {
    ContextMenu {
      Button(action: { viewStore.send(.selectModelTapped) }) { Text("Select") }
      Button(action: { viewStore.send(.deleteModelTapped) }) { Text("Delete") }
    }
  }
}

// MARK: - ActiveButtonStyle

struct ActiveButtonStyle: ButtonStyle {
  var isActive: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, .grid(4))
      .padding(.vertical, .grid(2))
      .font(.DS.headlineS)
      .background {
        LinearGradient.easedGradient(colors: [
          Color.DS.Background.success.lighten(by: 0.03),
          Color.DS.Background.success.darken(by: 0.07),
          Color.DS.Background.success.darken(by: 0.1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
          .continuousCornerRadius(.grid(2))
          .shadow(color: Color.DS.Background.success.darken(by: 0.2).opacity(configuration.isPressed ? 0 : 0.7), radius: 4, x: 0, y: 0)
          .opacity(isActive ? 1 : 0)
      }
      .addBorder(Color.DS.Background.success.opacity(isActive ? 0 : 0.3), width: 2, cornerRadius: .grid(2))
      .foregroundColor(isActive ? Color.DS.Text.base : Color.DS.Text.subdued)
      .cornerRadius(.grid(2))
  }
}

extension View {
  func activeButtonStyle(isActive: Bool) -> some View {
    buttonStyle(ActiveButtonStyle(isActive: isActive))
  }
}

// MARK: - Previews

#if DEBUG

  struct ModelRowView_Previews: PreviewProvider {
    static var previews: some View {
      ModelRowView(
        store: Store(
          initialState: ModelRow.State(
            model: .fixture,
            isSelected: true
          ),
          reducer: { ModelRow() }
        )
      )
    }
  }
#endif
