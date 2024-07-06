import ComposableArchitecture
import SwiftUI
import Inject
import Common

// MARK: - PremiumFeaturesSection

@Reducer
struct PremiumFeaturesSection {
  @ObservableState
  struct State: Equatable {
    var isLiveTranscriptionPurchased: Bool
    @Presents var purchaseModal: PurchaseLiveTranscriptionModal.State?
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case liveTranscriptionToggled
    case purchaseModal(PresentationAction<PurchaseLiveTranscriptionModal.Action>)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .liveTranscriptionToggled:
        if !state.isLiveTranscriptionPurchased {
          state.purchaseModal = PurchaseLiveTranscriptionModal.State()
          return .none
        }
        return .none
      case .purchaseModal(.presented(.delegate(.didFinishTransaction))):
        state.purchaseModal = nil
        return .none
      case .binding, .purchaseModal:
        return .none
      }
    }
    .ifLet(\.$purchaseModal, action: \.purchaseModal) {
      PurchaseLiveTranscriptionModal()
    }
  }
}

// MARK: - PremiumFeaturesSectionView

struct PremiumFeaturesSectionView: View {
  @Perception.Bindable var store: StoreOf<PremiumFeaturesSection>

  @ObserveInjection var injection

  var body: some View {
    WithPerceptionTracking {
      Section("Premium Features") {
        SettingsToggleButton(
          icon: .system(name: "waveform", background: .DS.Background.accent),
          title: "Live Transcription",
          isOn: $store.isLiveTranscriptionPurchased
        ) {
          store.send(.liveTranscriptionToggled)
        }
      }
      .sheet(
        store: store.scope(state: \.$purchaseModal, action: \.purchaseModal)
      ) { store in
        PurchaseLiveTranscriptionModalView(store: store)
      }
      .listRowBackground(Color.DS.Background.secondary)
      .listRowSeparator(.hidden)
      .enableInjection()
    }
  }
}
