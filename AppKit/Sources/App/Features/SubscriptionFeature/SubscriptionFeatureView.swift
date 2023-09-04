//
// Created by Igor Tarasenko on 03/09/2023.
//

import Foundation
import AppDevUtils
import Inject
import SwiftUI
import ComposableArchitecture

public struct SubscriptionFeature: ReducerProtocol {
  public struct State: Equatable {
    @BindingState var text = ""
    @BindingState var toggleIsOn = false
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case resetButtonTapped
  }

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding(\.$text):
        return .none

      case .binding:
        return .none

      case .resetButtonTapped:
        state = State()
        return .none
      }
    }
  }
}

public struct SubscriptionFeatureView: View {
  @ObserveInjection var inject

  let store: StoreOf<SubscriptionFeature>

  public init(store: StoreOf<SubscriptionFeature>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Form {
        HStack {
          TextField("Type here", text: viewStore.binding(\.$text))
            .disableAutocorrection(true)
            .foregroundStyle(viewStore.toggleIsOn ? Color.secondary : .primary)
        }
        .disabled(viewStore.toggleIsOn)

        Toggle(
          "Disable other controls",
          isOn: viewStore.binding(\.$toggleIsOn)
            .resignFirstResponder()
        )

        Button("Reset") {
          viewStore.send(.resetButtonTapped)
        }
        .tint(.red)
      }
    }
    .navigationTitle("Form")
    .enableInjection()
  }
}

#if DEBUG
struct SubscriptionFeatureView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      SubscriptionFeatureView(
        store: Store(
          initialState: SubscriptionFeature.State(),
          reducer: { SubscriptionFeature() }
        )
      )
    }
  }
}
#endif
