
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - SubscriptionDetails

struct SubscriptionDetails: ReducerProtocol {
  struct State: Equatable {
    var isPurchasing: Bool = false
  }

  enum Action: Equatable {
    case termsOfUseTapped
    case privacyPolicyTapped
    case restorePurchasesTapped
    case purchaseMonthlyTapped
    case purchaseYearlyTapped
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { _, action in
      switch action {
      default:
        return .none
      }
    }
  }
}

// MARK: - SubscriptionDetailsView

struct SubscriptionDetailsView: View {
  @ObserveInjection var inject

  let store: StoreOf<SubscriptionDetails>

  init(store: StoreOf<SubscriptionDetails>) {
    self.store = store
  }

  var body: some View {
    WithViewStore(store, observe: { $0 }) { _ in
      Text("SubscriptionDetails Feature")
    }
    .navigationTitle("SubscriptionDetails")
    .enableInjection()
  }
}

#if DEBUG
  struct SubscriptionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        SubscriptionDetailsView(
          store: Store(
            initialState: SubscriptionDetails.State(),
            reducer: { SubscriptionDetails() }
          )
        )
      }
    }
  }
#endif
