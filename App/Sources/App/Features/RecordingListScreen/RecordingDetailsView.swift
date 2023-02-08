import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingDetails

public struct RecordingDetails: ReducerProtocol {
  public struct State: Equatable {
    @BindingState var recordingInfo: RecordingInfo
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
  }

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Reduce { _, action in
      switch action {
      case .binding:
        return .none
      }
    }
  }
}

// MARK: - RecordingDetailsView

public struct RecordingDetailsView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordingDetails>

  public init(store: StoreOf<RecordingDetails>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { _ in
      Form {}
    }
    .navigationTitle("Recording Details")
    .enableInjection()
  }
}

#if DEBUG
  struct RecordingDetailsView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordingDetailsView(
          store: Store(
            initialState: RecordingDetails.State(recordingInfo: .mock),
            reducer: RecordingDetails()
          )
        )
      }
    }
  }
#endif
