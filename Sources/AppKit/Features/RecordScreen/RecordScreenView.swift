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
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case micSelector(MicSelector.Action)
    case recordingControls(RecordingControls.Action)
    case alert(PresentationAction<Alert>)
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
        // In case it was transcribed during the recording, we want to mark it as done
        var recordingInfo = recording.recordingInfo
        recordingInfo.transcription?.status = .done(Date())

        return .send(.delegate(.newRecordingCreated(recordingInfo)))

      case let .recordingControls(.recording(.delegate(.didFinish(.failure(error))))):
        state.alert = AlertState(
          title: TextState("Voice recording failed."),
          message: TextState(error.localizedDescription)
        )
        return .none

      case .delegate:
        return .none

      case .recordingControls:
        return .none

      case .micSelector:
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
