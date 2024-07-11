import AudioProcessing
import Common
import ComposableArchitecture
import Inject
import Pow
import SwiftUI

// MARK: - RecordScreen

@Reducer
struct RecordScreen {
  @ObservableState
  struct State: Then {
    @Presents var alert: AlertState<Action.Alert>?
    var micSelector = MicSelector.State()
    var recordingControls = RecordingControls.State()
    var liveTranscriptionSelector = LiveTranscriptionModelSelector.State()
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case micSelector(MicSelector.Action)
    case recordingControls(RecordingControls.Action)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)
    case liveTranscriptionSelector(LiveTranscriptionModelSelector.Action)

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

    Scope(state: \.liveTranscriptionSelector, action: /Action.liveTranscriptionSelector) {
      LiveTranscriptionModelSelector()
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

      case .delegate:
        return .none

      case .binding:
        return .none

      case .alert:
        return .none

      case .liveTranscriptionSelector:
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
      VStack(spacing: .grid(6)) {
        MicSelectorView(store: store.scope(state: \.micSelector, action: \.micSelector))

        if store.state.recordingControls.recording == nil, store.state.liveTranscriptionSelector.premiumFeatures.isProductFound == true {
          LiveTranscriptionModelSelectorView(store: store.scope(state: \.liveTranscriptionSelector, action: \.liveTranscriptionSelector))
            .transition(.movingParts.blur.combined(with: .opacity))
        }

        Spacer()

        RecordingControlsView(store: store.scope(state: \.recordingControls, action: \.recordingControls))
      }
      .padding(.grid(4))
      .padding(.horizontal, .grid(2))
      .alert($store.scope(state: \.alert, action: \.alert))
    }
  }
}
