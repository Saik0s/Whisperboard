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
    case buyLiveTranscriptionTapped
    case purchaseModal(PresentationAction<PurchaseLiveTranscriptionModal.Action>)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .buyLiveTranscriptionTapped:
        state.purchaseModal = PurchaseLiveTranscriptionModal.State()
        return .none
      case .purchaseModal(.presented(.delegate(.didFinishTransaction))):
        state.purchaseModal = nil
        state.isLiveTranscriptionPurchased = true
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
        HStack {
          Label {
            Text("Live Transcription")
          } icon: {
            Image(systemName: "waveform")
              .foregroundColor(.white)
              .padding(6)
              .background(Color.DS.Background.accent)
              .clipShape(Circle())
          }
          
          Spacer()
          
          if store.isLiveTranscriptionPurchased {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
          } else {
            Button("Buy") {
              store.send(.buyLiveTranscriptionTapped)
            }
            .buttonStyle(.borderedProminent)
          }
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
