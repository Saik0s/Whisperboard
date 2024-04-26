import AsyncAlgorithms
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - ModelRow

@Reducer
struct ModelRow {
  @ObservableState
  struct State: Equatable, Identifiable {
    var model: VoiceModel

    var isSelected: Bool

    var isRemovingModel = false

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

  var body: some Reducer<State, Action> {
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
        logs.error("Failed to download model: \(error)")
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

  @Perception.Bindable var store: StoreOf<ModelRow>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(2)) {
        HStack(spacing: .grid(2)) {
          VStack(alignment: .leading, spacing: .grid(1)) {
            VStack(alignment: .leading, spacing: 0) {
              Text(store.model.modelType.readableName)
                .textStyle(.headline)

              Text(store.model.modelType.sizeLabel)
                .textStyle(.subheadline)
            }

            Text(store.model.modelType.modelDescription)
              .textStyle(.captionBase)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          if store.isRemovingModel {
            ProgressView()
          } else if store.model.isDownloading {
            Button("Cancel") { store.send(.cancelDownloadTapped) }
              .tertiaryButtonStyle()
          } else if store.model.isDownloaded == false {
            Button("Download") { store.send(.downloadModelTapped) }
              .secondaryButtonStyle()
          } else {
            Button("Active") { store.send(.selectModelTapped) }
              .activeButtonStyle(isActive: store.isSelected)
          }
        }

        if store.model.isDownloading {
          ProgressView(value: store.model.downloadProgress)
        }
      }
      .foregroundColor(store.isSelected ? Color.DS.Text.success : Color.DS.Text.base)
      .contentShape(Rectangle())
      .onTapGesture { store.send(.selectModelTapped) }
      .contextMenu(store.model.isDownloaded && store.model.modelType != .tiny ? contextMenuBuilder() : nil)
    }
    .enableInjection()
  }

  func contextMenuBuilder() -> ContextMenu<TupleView<(Button<Text>, Button<Text>)>> {
    ContextMenu {
      Button(action: { store.send(.selectModelTapped) }) { Text("Select") }
      Button(action: { store.send(.deleteModelTapped) }) { Text("Delete") }
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
      .textStyle(.secondaryButton)
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
