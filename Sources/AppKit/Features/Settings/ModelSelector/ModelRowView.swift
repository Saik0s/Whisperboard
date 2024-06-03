import AsyncAlgorithms
import AudioProcessing
import Common
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - ModelRow

@Reducer
struct ModelRow {
  @ObservableState
  struct State: Equatable, Identifiable {
    var id: String { model }
    var model: String
    var isRemovingModel = false
    var progress: Double = 0
    var isDownloaded: Bool { progress == 1 }
    var isDownloading: Bool { progress < 0.99 && progress > 0.01 }
  }

  enum Action: Equatable {
    case downloadModelTapped
    case selectModelTapped
    case modelUpdated(progress: Double)
    case loadError(String)
    case deleteModelTapped
    case cancelDownloadTapped
    case didRemoveModel(Result<Void, EquatableError>)
  }

  struct CancelDownloadID: Hashable {}

  @Dependency(RecordingTranscriptionStream.self) var recordingTranscriptionStream

  var body: some Reducer<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .downloadModelTapped:
        guard !state.isDownloading else { return .none }

        state.progress = 0.01

        return .run { [model = state.model] send in
          for await downloadState in recordingTranscriptionStream.loadModel(model) {
            switch downloadState {
            case let .inProgress(progress, _):
               await send(.modelUpdated(progress: progress))

            case .success:
              await send(.modelUpdated(progress: 1))
              await send(.selectModelTapped)

            case let .failure(error, _):
              await send(.loadError(error.localizedDescription))
            }
          }
        }.cancellable(id: CancelDownloadID(), cancelInFlight: true)

      case .selectModelTapped:
        return .none

      case let .modelUpdated(progress):
        state.progress = progress
        return .none

      case .deleteModelTapped:
        guard state.isDownloaded else { return .none }

        state.isRemovingModel = true
        return .run { [model = state.model] send in
          await send(.didRemoveModel(Result { try await recordingTranscriptionStream.deleteModel(model) }.mapError { $0.equatable() }))
        }

      case .didRemoveModel(.success):
        state.isRemovingModel = false
        return .none

      case let .didRemoveModel(.failure(error)):
        logs.error("Failed to remove model: \(error)")
        state.isRemovingModel = false
        return .none

      case let .loadError(error):
        logs.error("Failed to download model: \(error)")
        state.progress = 0
        return .none

      case .cancelDownloadTapped:
        state.progress = 0
        return .cancel(id: CancelDownloadID())
      }
    }
  }
}

// MARK: - ModelRowView

struct ModelRowView: View {
  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<ModelRow>

  var isSelected: Bool

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(2)) {
        HStack(spacing: .grid(2)) {
          VStack(alignment: .leading, spacing: .grid(1)) {
            VStack(alignment: .leading, spacing: 0) {
              Text(store.model)
                .textStyle(.headline)
//              Text(store.model.modelType.sizeLabel)
//                .textStyle(.subheadline)
            }

            // TODO: description
//            Text(store.model.modelType.modelDescription)
//              .textStyle(.captionBase)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          if store.isRemovingModel {
            ProgressView()
          } else if store.isDownloading {
            Button("Cancel") { store.send(.cancelDownloadTapped) }
              .tertiaryButtonStyle()
          } else if store.model.isDownloaded == false {
            Button("Download") { store.send(.downloadModelTapped) }
              .secondaryButtonStyle()
          } else {
            Button("Active") { store.send(.selectModelTapped) }
              .activeButtonStyle(isActive: isSelected)
          }
        }

        if store.model.isDownloading {
          ProgressView(value: store.model.downloadProgress)
        }
      }
      .foregroundColor(isSelected ? Color.DS.Text.success : Color.DS.Text.base)
      .contentShape(Rectangle())
      .onTapGesture { store.send(.selectModelTapped) }
      .contextMenu(store.isDownloaded ? contextMenuBuilder() : nil)
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
          initialState: ModelRow.State(model: .fixture),
          reducer: { ModelRow() }
        ),
        isSelected: false
      )
    }
  }
#endif
