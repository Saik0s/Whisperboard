import AudioProcessing
import Common
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordScreen

@Reducer
struct RecordScreen {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var micSelector = MicSelector.State()
    var recordingControls = RecordingControls.State()
    var availableModels: [Model] = []

    @Shared var selectedModelName: String
    @Shared(.isLiveTranscriptionSupported) var isLiveTranscriptionSupported: Bool

    init() {
      @Shared(.settings) var settings
      _selectedModelName = $settings.selectedModelName
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case micSelector(MicSelector.Action)
    case recordingControls(RecordingControls.Action)
    case alert(PresentationAction<Alert>)
    case modelSelected(Model.ID)
    case delegate(Delegate)

    enum Alert: Equatable {}

    enum Delegate: Equatable {
      case newRecordingCreated(RecordingInfo)
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.micSelector, action: /Action.micSelector) {
      MicSelector()
    }

    Scope(state: \.recordingControls, action: /Action.recordingControls) {
      RecordingControls()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case let .recordingControls(.recording(.delegate(.didFinish(.success(recording))))):
        // In case recording process has finished successfully, we want to mark transcription as done
        var recordingInfo = recording.recordingInfo
        recordingInfo.transcription?.status = .done(Date())

        return .send(.delegate(.newRecordingCreated(recordingInfo)))

      case let .recordingControls(.recording(.delegate(.didFinish(.failure(error))))):
        state.alert = AlertState(
          title: TextState("Voice recording failed."),
          message: TextState(error.localizedDescription)
        )
        return .none

      case .recordingControls:
        return .none

      case .micSelector:
        return .none

      case let .modelSelected(modelID):
        state.selectedModelName = modelID
        return .none

      case .delegate:
        return .none

      case .binding:
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - RecordScreenView

struct RecordScreenView: View {
  @Perception.Bindable var store: StoreOf<RecordScreen>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: 0) {
        MicSelectorView(store: store.scope(state: \.micSelector, action: \.micSelector))

        LiveTranscriptionSelector(
          selectedModel: $store.selectedModelName,
          availableModels: store.availableModels,
          isFeaturePurchased: store.isLiveTranscriptionSupported
        )
        .padding(.top, .grid(2))

        Spacer()

        RecordingControlsView(store: store.scope(state: \.recordingControls, action: \.recordingControls))
      }
      .padding(.top, .grid(4))
      .padding(.horizontal, .grid(4))
      .padding(.bottom, .grid(8))
      .ignoresSafeArea(edges: .bottom)
      .alert($store.scope(state: \.alert, action: \.alert))
    }
  }
}
