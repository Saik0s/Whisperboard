import ComposableArchitecture
import SwiftUI
import Inject
import Common
import StoreKit

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
    case onTask
    case checkPurchaseStatus(Bool)
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
      case .onTask:
        return .run { send in
          let productID = "me.igortarasenko.Whisperboard.liveTranscription"
          let products = try await Product.products(for: [productID])
          guard let product = products.first else { return }
          let isPurchased = await product.currentEntitlement != nil
          await send(.checkPurchaseStatus(isPurchased))
        }
      case let .checkPurchaseStatus(isPurchased):
        state.isLiveTranscriptionPurchased = isPurchased
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
        SettingsButton(
          icon: .system(name: "waveform", background: Color.DS.Background.accent),
          title: "Live Transcription",
          trailingText: store.isLiveTranscriptionPurchased ? "Purchased" : "Not Purchased",
          indicator: store.isLiveTranscriptionPurchased ? nil : .chevron
        ) {
          if !store.isLiveTranscriptionPurchased {
            store.send(.buyLiveTranscriptionTapped)
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
      .task { await store.send(.onTask).finish() }
    }
  }
}
