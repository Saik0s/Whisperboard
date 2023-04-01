import AppDevUtils
import ComposableArchitecture
import SwiftUI

// MARK: - ModelRow

struct ModelRow: ReducerProtocol {
  struct State: Equatable, Identifiable {
    var model: VoiceModel
    var isSelected: Bool
    var id: VoiceModel.ID { model.id }
  }

  enum Action: Equatable {
    case downloadModelTapped
    case selectModelTapped
    case modelUpdated(VoiceModel)
    case loadError(String)
    case deleteModelTapped
  }

  @Dependency(\.modelDownload) var modelDownload: ModelDownloadClient
  @Dependency(\.transcriber) var transcriber: TranscriberClient

  struct CancelDownloadID: Hashable {}

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .downloadModelTapped:
        guard state.model.isDownloading == false else {
          return .none
        }
        state.model.isDownloading = true
        return .run { [modelType = state.model.modelType] send in
          for await downloadState in await modelDownload.downloadModel(modelType) {
            switch downloadState {
            case let .inProgress(progress):
              await send(.modelUpdated(VoiceModel(modelType: modelType, isDownloading: true, downloadProgress: progress)))
            case .success:
              await send(.modelUpdated(VoiceModel(modelType: modelType, isDownloading: false, downloadProgress: 1)))
            case let .failure(error):
              await send(.loadError(error.localizedDescription))
            }
          }
        }
        .cancellable(id: CancelDownloadID(), cancelInFlight: true)

      case .selectModelTapped:
        guard state.isSelected == false else {
          return .none
        }
        transcriber.selectModel(state.model.modelType)
        return .none

      case let .modelUpdated(model):
        state.model = model
        return .none

      case .deleteModelTapped:
        guard state.model.isDownloaded else {
          return .none
        }
        return .fireAndForget { [state] in
          modelDownload.deleteModel(state.model.modelType)
        }

      case let .loadError(error):
        log.error(error)
        state.model.isDownloading = false
        return .none
      }
    }
  }
}

// MARK: - ModelRowView

struct ModelRowView: View {
  let store: StoreOf<ModelRow>
  @ObservedObject var viewStore: ViewStoreOf<ModelRow>

  init(store: StoreOf<ModelRow>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    HStack {
      Toggle("", isOn: viewStore.binding(get: { $0.isSelected }, send: { _ in .selectModelTapped }))
        .toggleStyle(RadioButtonStyle())

      VStack(alignment: .leading, spacing: .grid(2)) {
        Text(viewStore.model.modelType.rawValue)
          .font(.DS.headlineM)
          .foregroundColor(Color.DS.Text.base)
        Text(viewStore.model.modelType.sizeLabel)
          .font(.DS.captionS)
          .foregroundColor(Color.DS.Text.subdued)
      }

      Spacer()

      if viewStore.model.isDownloading {
        ProgressView(value: viewStore.model.downloadProgress)
      } else if viewStore.model.isDownloaded == false {
        Button("Download") { viewStore.send(.downloadModelTapped) }
          .secondaryButtonStyle()
      }
    }
    .foregroundColor(viewStore.isSelected ? Color.DS.Text.success : Color.DS.Text.base)
    .frame(height: 40)
    .contentShape(Rectangle())
    .onTapGesture { viewStore.send(.selectModelTapped) }
    .contextMenu(viewStore.model.isDownloaded && viewStore.model.modelType != .tiny ? contextMenuBuilder() : nil)
  }

  func contextMenuBuilder() -> ContextMenu<TupleView<(Button<Text>, Button<Text>)>> {
    ContextMenu {
      Button(action: { viewStore.send(.selectModelTapped) }) {
        Text("Select")
      }
      Button(action: { viewStore.send(.deleteModelTapped) }) {
        Text("Delete")
      }
    }
  }
}

// MARK: - RadioButtonStyle

struct RadioButtonStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button(action: { configuration.isOn.toggle() }) {
      HStack {
        Image(systemName: configuration.isOn ? "largecircle.fill.circle" : "circle")
          .foregroundColor(configuration.isOn ? .accentColor : .secondary)
      }
    }
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
          reducer: ModelRow()
        )
      )
    }
  }
#endif
