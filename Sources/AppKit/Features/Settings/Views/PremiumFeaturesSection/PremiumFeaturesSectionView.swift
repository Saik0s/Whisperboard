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
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
  }
}

// MARK: - PremiumFeaturesSectionView

struct PremiumFeaturesSectionView: View {
  @Perception.Bindable var store: StoreOf<PremiumFeaturesSection>

  @ObserveInjection var injection

  var body: some View {
    WithPerceptionTracking {
      VStack {
        Text("Premium Features")
      }
      .enableInjection()
    }
  }
}
