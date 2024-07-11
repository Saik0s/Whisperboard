import AudioProcessing
import Common
import ComposableArchitecture
import Foundation
import Inject
import SwiftUI
import WhisperKit

// MARK: - ModelSelector

@Reducer
struct ModelSelector {
  @ObservableState
  struct State: Equatable {
    struct LoadingProgress: Equatable {
      var id: Model.ID
      var progress: Double
    }

    struct ModelInfo: Equatable, Identifiable {
      var id: Model.ID { model.id }
      var model: Model
      var title: String
      var info: String
      var isMultilingual: Bool
      var isTurbo: Bool
      var isDistilled: Bool
      var size: String
      var position: Int
    }

    var localModels: IdentifiedArrayOf<ModelInfo> = []
    var availableModels: IdentifiedArrayOf<ModelInfo> = []
    var disabledModels: IdentifiedArrayOf<ModelInfo> = []
    var hasAnythingInModelsDir = false

    var loadQueue: Set<Model.ID> = []
    @Shared var loadingProgress: LoadingProgress?
    @Shared(.settings) var settings: Settings

    @Presents var alert: AlertState<Action.Alert>?

    var selectedModelID: Model.ID {
      get { settings.selectedModelName }
      set { settings.selectedModelName = newValue }
    }

    var selectedModelLabel: String {
      localModels.first(where: { $0.id == selectedModelID })?.title ?? "None"
    }

    var noLocalModels: Bool {
      !(localModels + availableModels).elements.contains { $0.model.isLocal }
        && !availableModels.isEmpty
    }

    init() {
      _loadingProgress = Shared(nil)
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case downloadButtonTapped(Model.ID)
    case downloadTask(id: Model.ID, TaskResult<Void>)
    case reloadModels
    case modelsResponse(TaskResult<[State.ModelInfo]>)
    case cancelDownloadButtonTapped(Model.ID)
    case deleteModelButtonTapped(Model.ID)
    case deleteAllModelsButtonTapped
    case selectModelButtonTapped(Model.ID)
    case setModelsDirNotEmpty

    case alert(PresentationAction<Alert>)

    enum Alert: Equatable {}
  }

  enum CancelID: Hashable { case modelID(Model.ID) }

  @Dependency(RecordingTranscriptionStream.self) var transcriptionStream: RecordingTranscriptionStream

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .downloadButtonTapped(id):
        guard state.loadingProgress == nil else {
          if state.loadingProgress?.id != id {
            state.loadQueue.insert(id)
          }
          return .none
        }

        return loadModel(state: &state, id: id)

      case let .downloadTask(id: id, .success):
        state.loadingProgress = nil
        state.selectedModelID = id
        return loadNextInQueue(state: &state)

      case let .downloadTask(id: _, .failure(error)):
        state.loadingProgress = nil
        state.alert = .error(message: error.localizedDescription)
        return loadNextInQueue(state: &state)

      case .reloadModels:
        return fetchModels()

      case let .modelsResponse(.success(newModels)):
        let models = newModels.filter { $0.position <= 100 }
        @Shared(.availableModels) var _models
        _models = models
        state.localModels = models.filter { $0.model.isLocal && !$0.model.isDisabled }.identifiedArray
        state.availableModels = models.filter { !$0.model.isLocal && !$0.model.isDisabled }.identifiedArray
        state.disabledModels = models.filter(\.model.isDisabled).identifiedArray
        return .none

      case let .modelsResponse(.failure(error)):
        state.alert = .error(message: error.localizedDescription)
        return .none

      case let .cancelDownloadButtonTapped(id):
        state.loadQueue.remove(id)
        if state.loadingProgress?.id == id {
          logs.debug("Cancelled current download of \(id)")
          state.loadingProgress = nil
          return .cancel(id: CancelID.modelID(id))
        }
        return .none

      case let .deleteModelButtonTapped(id):
        if let defaultModel = state.localModels.first(where: { $0.id != id })?.id,
           state.selectedModelID == id {
          state.selectedModelID = defaultModel
        }
        return .run { send in
          try await transcriptionStream.deleteModel(id)
          await send(.reloadModels)
        }

      case .deleteAllModelsButtonTapped:
        return .run { send in
          try await transcriptionStream.deleteAllModels()
          await send(.reloadModels)
        }

      case let .selectModelButtonTapped(id):
        state.selectedModelID = id
        return .none

      case .setModelsDirNotEmpty:
        state.hasAnythingInModelsDir = true
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }

  private func loadNextInQueue(state: inout State) -> Effect<Action> {
    if let id = state.loadQueue.first {
      .merge(
        loadModel(state: &state, id: id),
        fetchModels()
      )
    } else {
      fetchModels()
    }
  }

  private func loadModel(state: inout State, id: Model.ID) -> Effect<Action> {
    state.loadQueue.remove(id)
    state.loadingProgress = State.LoadingProgress(id: id, progress: 0)
    return .run { [loadingProgress = state.$loadingProgress] send in
      await send(.downloadTask(id: id, TaskResult {
        try await transcriptionStream.loadModel(id) { progress in
          loadingProgress.wrappedValue?.progress = progress
        }
        logs.debug("Loaded model \(id) isCancelled: \(Task.isCancelled)")
      }))
    }
    .cancellable(id: CancelID.modelID(id), cancelInFlight: true)
  }

  private func fetchModels() -> Effect<Action> {
    .run { send in
      await send(.modelsResponse(TaskResult { try await transcriptionStream.fetchModels().map(modelAttributes(for:)) }))
      if directoryExistsAndNotEmptyAtPath(TranscriptionStream.modelDirURL.path()) {
        await send(.setModelsDirNotEmpty)
      }
    }
  }
}

// MARK: - ModelSelectorView

struct ModelSelectorView: View {
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>

  var body: some View {
    WithPerceptionTracking {
      NavigationView {
        List {
          DownloadedSection(store: store)
          AvailableSection(store: store)
//          NotSupportedSection(store: store)
        }
        .onAppear { store.send(.reloadModels) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .navigationTitle("Models")
      }
    }
  }
}

// MARK: - DownloadedSection

private struct DownloadedSection: View {
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>

  var body: some View {
    WithPerceptionTracking {
      Section(header: Text("Downloaded")) {
        ForEach(store.localModels) { model in
          ModelRow(store: store, model: model, isDownloaded: true)
        }
        if !store.localModels.isEmpty {
          Button("Delete All") {
            store.send(.deleteAllModelsButtonTapped)
          }
          .foregroundColor(.red)
        }
      }
    }
  }
}

// MARK: - AvailableSection

private struct AvailableSection: View {
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>

  var body: some View {
    WithPerceptionTracking {
      Section(header: Text("Available")) {
        ForEach(store.availableModels) { model in
          ModelRow(store: store, model: model, isDownloaded: false)
        }
      }
    }
  }
}

// MARK: - NotSupportedSection

private struct NotSupportedSection: View {
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>

  var body: some View {
    WithPerceptionTracking {
      Section(header: Text("Not Supported")) {
        ForEach(store.disabledModels) { model in
          WithPerceptionTracking {
            VStack(alignment: .leading) {
              ModelInfoView(model: model)
              Text(model.info)
                .textStyle(.subheadline)
                .lineLimit(3)
                .allowsTightening(true)
            }
          }
        }
      }
    }
  }
}

// MARK: - ModelRow

private struct ModelRow: View {
  @Perception.Bindable var store: Store<ModelSelector.State, ModelSelector.Action>
  let model: ModelSelector.State.ModelInfo
  let isDownloaded: Bool

  var body: some View {
    WithPerceptionTracking {
      VStack {
        HStack {
          ModelInfoView(model: model)
          Spacer()
          if isDownloaded {
            Button(store.selectedModelID == model.id ? "Active" : "Select") {
              store.send(.selectModelButtonTapped(model.id))
            }
            .activeButtonStyle(isActive: store.selectedModelID == model.id)
          } else {
            if store.loadingProgress?.id != model.id, !store.loadQueue.contains(model.id) {
              Button("Download") {
                store.send(.downloadButtonTapped(model.id))
              }
              .secondaryButtonStyle()
            }
          }
        }

        Text(model.info)
          .textStyle(.body)
          .lineLimit(5)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let progress = store.loadingProgress, progress.id == model.id {
          ProgressView(value: progress.progress)
        } else if store.loadQueue.contains(model.id) {
          ProgressView()
        }
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
          store.send(.deleteModelButtonTapped(model.id))
        } label: {
          Image(systemName: "trash")
        }
      }
      .contentShape(Rectangle())
      .contextMenu(contextMenuBuilder(id: model.id))
    }
  }

  func contextMenuBuilder(id: Model.ID) -> ContextMenu<TupleView<(Button<Text>, Button<Text>)>> {
    ContextMenu {
      Button(action: { store.send(.selectModelButtonTapped(id)) }) { Text("Select") }
      Button(action: { store.send(.deleteModelButtonTapped(id)) }) { Text("Delete") }
    }
  }
}

// MARK: - ModelInfoView

struct ModelInfoView: View {
  let model: ModelSelector.State.ModelInfo

  var body: some View {
    VStack(alignment: .leading, spacing: .grid(1)) {
      Text(model.title)
        .textStyle(.bodyBold)

      Text(model.size)
        .textStyle(.sublabel)

//      HStack {

//        Text(model.isMultilingual && !model.isDistilled ? "Multilingual" : "English")
//          .font(.DS.footnote)
//          .foregroundStyle(Color.DS.neutral01100)
//          .opacity(0.8)
//          .padding(.horizontal, 2)
//          .padding(.vertical, 1)
//          .background(
//            RoundedRectangle(cornerRadius: 2)
//              .stroke(Color.DS.code02, lineWidth: 1)
//              .shadow(color: Color.DS.code02.opacity(0.8), radius: 4, x: 0, y: 0)
//          )
//          .scaleEffect(0.9)
//
//        if model.isTurbo {
//          Text("Turbo")
//            .font(.DS.footnote)
//            .allowsTightening(true)
//            .foregroundStyle(Color.DS.code03)
//            .opacity(0.8)
//            .padding(.horizontal, 2)
//            .padding(.vertical, 1)
//            .background(
//              RoundedRectangle(cornerRadius: 2)
//                .stroke(Color.DS.code03, lineWidth: 1)
//                .shadow(color: Color.DS.code03.opacity(0.8), radius: 4, x: 0, y: 0)
//            )
//            .scaleEffect(0.9)
//        }
//
//        if model.isDistilled {
//          Text("Distilled")
//            .font(.DS.footnote)
//            .allowsTightening(true)
//            .foregroundStyle(Color.DS.code04)
//            .opacity(0.8)
//            .padding(.horizontal, 2)
//            .padding(.vertical, 1)
//            .background(
//              RoundedRectangle(cornerRadius: 2)
//                .stroke(Color.DS.code04, lineWidth: 1)
//                .shadow(color: Color.DS.code04.opacity(0.8), radius: 4, x: 0, y: 0)
//            )
//            .scaleEffect(0.9)
//        }
//      }
    }
    .accessibilityElement(children: .combine)
  }
}

// MARK: - ActiveButtonStyle

struct ActiveButtonStyle: ButtonStyle {
  var isActive: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, .grid(4))
      .padding(.vertical, .grid(2))
      .foregroundColor(isActive ? Color.DS.Text.base : Color.DS.Text.subdued)
      .textStyle(.secondaryButton)
      .background {
        LinearGradient.easedGradient(colors: [
          Color.DS.Background.success.darken(by: 0.1),
          Color.DS.Background.success.darken(by: 0.2),
          Color.DS.Background.success.darken(by: 0.27),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
          .continuousCornerRadius(.grid(2))
          .shadow(color: Color.DS.Background.success.darken(by: 0.2).opacity(configuration.isPressed ? 0 : 0.7), radius: 4, x: 0, y: 0)
          .opacity(isActive ? 1 : 0)
      }
      .addBorder(Color.DS.Background.success.opacity(isActive ? 0 : 0.3), width: 2, cornerRadius: .grid(2))
      .cornerRadius(.grid(2))
  }
}

extension View {
  func activeButtonStyle(isActive: Bool) -> some View {
    buttonStyle(ActiveButtonStyle(isActive: isActive))
  }
}

private func modelAttributes(for model: Model) -> ModelSelector.State.ModelInfo {
  let isMultilingual = !model.name.contains(".en")
  let isTurbo = model.name.contains("turbo")
  let isDistilled = model.name.contains("distil")
  let isEnglishOnly: Bool = !isMultilingual || isDistilled
  var size = model.name.range(of: "\\d+MB", options: .regularExpression).map { String(model.name[$0]).replacingOccurrences(of: "MB", with: " MB") }
  var title: String
  let info: String
  var position: Int

  switch model.name {
  case _ where model.name.contains("tiny"):
    title = "Tiny"
    if size == nil { size = "75 MB" }
    position = isEnglishOnly ? 10 : 11

  case _ where model.name.contains("base"):
    title = "Base"
    if size == nil { size = "142 MB" }
    position = isEnglishOnly ? 20 : 21

  case _ where model.name.contains("small"):
    title = "Small"
    if size == nil { size = "466 MB" }
    position = isEnglishOnly ? 30 : 31

  case _ where model.name.contains("medium"):
    title = "Medium"
    if size == nil { size = "1.5 GB" }
    position = isEnglishOnly ? 40 : 41

  case _ where model.name.contains("large-v2"):
    title = "Large v2"
    if size == nil { size = "2.9 GB" }
    position = isEnglishOnly ? 160 : 161

  case _ where model.name.contains("large-v3"):
    title = "Large v3"
    if size == nil { size = isDistilled || isTurbo ? "-" : "2.9 GB" }
    position = isEnglishOnly ? 70 : 71

  case _ where model.name.contains("large"):
    title = "Large"
    if size == nil { size = "2.9 GB" }
    position = isEnglishOnly ? 150 : 151

  default:
    title = model.name.capitalized
    position = 100 // Default position for unknown models
  }
  
  if isEnglishOnly {
    title += " English"
  }
  
  if isTurbo {
    title += " Turbo"
  }

  info =
    "\(!isEnglishOnly ? "Supports Multiple Languages" : "English Only")\(isDistilled ? "\nAdditional improved" : "")\(isTurbo ? "\nTurbo Fast Optimization" : "")"

  position += isDistilled ? 2 : 0

  return ModelSelector.State.ModelInfo(
    model: model,
    title: title,
    info: info,
    isMultilingual: isMultilingual,
    isTurbo: isTurbo,
    isDistilled: isDistilled,
    size: size ?? "-",
    position: position
  )
}

private func directoryExistsAndNotEmptyAtPath(_ path: String) -> Bool {
  var isDirectory = ObjCBool(true)
  let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
  guard exists && isDirectory.boolValue else { return false }
  do {
    return try FileManager.default.contentsOfDirectory(atPath: path).isNotEmpty
  } catch {
    logs.error("Failed to check if directory exists and is not empty: \(error)")
    return false
  }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<InMemoryKey<[ModelSelector.State.ModelInfo]>> {
  static var availableModels: Self {
    PersistenceKeyDefault(.inMemory("availableModels"), [])
  }
}
