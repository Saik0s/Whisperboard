import ComposableArchitecture
import Inject
import SwiftUI
import VariableBlurView

// MARK: - SubscriptionSection

struct SubscriptionSection: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var details: SubscriptionDetails.State?
  }

  enum Action: Equatable {
    case details(PresentationAction<SubscriptionDetails.Action>)
    case sectionTapped
    case getAccessButtonTapped
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .details:
        return .none

      case .sectionTapped:
        guard state.details == nil else { return .none }
        state.details = .init()
        return .none

      case .getAccessButtonTapped:
        guard state.details == nil else { return .none }
        state.details = .init()
        return .none
      }
    }
    .ifLet(\.$details, action: /Action.details) {
      SubscriptionDetails()
    }
  }
}

// MARK: - SubscriptionSectionView

struct SubscriptionSectionView: View {
  @ObserveInjection var inject

  let store: StoreOf<SubscriptionSection>

  init(store: StoreOf<SubscriptionSection>) {
    self.store = store
  }

  var body: some View {
    Section {
      VStack(spacing: .grid(2)) {
        HStack {
          Text("WhisperBoard")
            .font(.title.weight(.medium).width(.condensed))
            .foregroundColor(.DS.Text.base)

          Text("PRO")
            .font(.title.weight(.medium).width(.compressed))
            .foregroundColor(.DS.Text.base)
            .padding(.horizontal, .grid(2))
            .background {
              RoundedRectangle(cornerRadius: .grid(1))
                .fill(Color.DS.Text.accent.darken(by: 0.1))
                .shadow(color: .DS.Text.accent.darken(by: 0.12), radius: 2, y: 2)
            }
        }
        .accessibilityElement(children: .combine)

        Text("Contribute to ongoing development and enjoy access to fantastic extra features!")
          .font(.DS.bodyS)
          .foregroundColor(.DS.Text.base)

        Button("Get Access") {
          store.send(.getAccessButtonTapped)
        }
        .primaryButtonStyle()
        .padding(.vertical, .grid(2))
      }
      .frame(maxWidth: .infinity)
      .multilineTextAlignment(.center)
      .padding(.top, .grid(40))
      .contentShape(Rectangle())
      .onTapGesture {
        store.send(.sectionTapped)
      }
      .sheet(store: store.scope(state: \.$details, action: SubscriptionSection.Action.details)) { store in
        SubscriptionDetailsView(store: store)
      }
    } header: {
      Text("Pro Features")
    }
    .listRowBackground(
      sectionBackground()
    )
    .listRowSeparator(.hidden)
    .enableInjection()
  }

  private func sectionBackground() -> some View {
    LinearGradient(
      colors: [
        .DS.Background.tertiary,
        .DS.Background.secondary,
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay {
      ZStack {
        WhisperBoardKitAsset.subscriptionHeader.swiftUIImage
          .resizable()
          .scaledToFit()
          .background(WhisperBoardKitAsset.subscriptionHeader.swiftUIImage.resizable().scaledToFit().blur(radius: 10))
          .padding(.horizontal, .grid(8))
          .offset(y: .grid(18) * -1)

        VariableBlurView()
          .rotationEffect(.degrees(180), anchor: .center)
          .padding(.top, .grid(32))
          .padding(1)
      }
    }
    .addBorder(
      LinearGradient(
        colors: [
          .DS.Background.tertiary.lighten().opacity(0.05),
          .DS.Background.tertiary.lighten().opacity(0.2),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      width: 1,
      cornerRadius: .grid(3)
    )
    .compositingGroup()
  }
}

#if DEBUG
  struct SubscriptionSectionView_Previews: PreviewProvider {
    static var previews: some View {
      Form {
        SubscriptionSectionView(
          store: Store(
            initialState: SubscriptionSection.State(),
            reducer: { SubscriptionSection() }
          )
        )
      }
      .scrollContentBackground(.hidden)
      .background(Color.DS.Background.primary)
      .colorScheme(.dark)
    }
  }
#endif
