import AppDevUtils
import ComposableArchitecture
import Inject
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
    case cancelDownloadTapped
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
              await send(.selectModelTapped)
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
        state.isSelected = true
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
    viewStore = ViewStore(store)
  }

  var body: some View {
    VStack(spacing: .grid(2)) {
      HStack(spacing: .grid(2)) {
        VStack(alignment: .leading, spacing: .grid(1)) {
          HStack(spacing: .grid(1)) {
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

        if viewStore.model.isDownloading {
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
    .padding(.horizontal, .grid(4))
    .padding(.vertical, .grid(2))
    .contentShape(Rectangle())
    .onTapGesture { viewStore.send(.selectModelTapped) }
    .contextMenu(viewStore.model.isDownloaded && viewStore.model.modelType != .tiny ? contextMenuBuilder() : nil)
    .animation(.easeInOut(duration: 0.2), value: viewStore.state)
    .enableInjection()
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

// MARK: - RadioButtonStyle

struct RadioButtonStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button(action: { configuration.isOn.toggle() }) {
      HStack {
        Image(systemName: configuration.isOn ? "largecircle.fill.circle" : "circle")
          .foregroundColor(configuration.isOn ? .systemGreen : .systemGray)
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
