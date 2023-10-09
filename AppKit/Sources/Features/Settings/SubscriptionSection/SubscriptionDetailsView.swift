import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - Terms

enum Terms: Hashable {
  case termsOfUse
  case subscriptionTerms
  case privacyPolicy
}

// MARK: - SubscriptionDetails

struct SubscriptionDetails: ReducerProtocol {
  struct State: Equatable {
    var purchaseProgress: ProgressiveResultOf<SubscriptionTransaction> = .none
    var availablePackages: ProgressiveResultOf<IdentifiedArrayOf<SubscriptionPackage>> = .none

    @PresentationState var alert: AlertState<Action.Alert>?
    @PresentationState var termsOverlay: Terms?

    var isSubscribed: Bool = false
  }

  enum Action: Equatable {
    case onTask

    case availablePackagesDidLoad(TaskResult<IdentifiedArrayOf<SubscriptionPackage>>)
    case purchasePackage(id: SubscriptionPackage.ID)
    case purchaseCompleted(TaskResult<SubscriptionTransaction>)
    case restorePurchaseCompleted(TaskResult<Bool>)

    case termsOfUseTapped
    case subscrtiptionTermsTapped
    case privacyPolicyTapped
    case restorePurchasesTapped

    case alert(PresentationAction<Alert>)
    case termsOverlay(PresentationAction<Terms>)

    case showAlert(AlertState<Action.Alert>)

    enum Alert: Equatable {}

    enum Terms: Equatable {}
  }

  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .onTask:
        return .run { send in
          await send(.availablePackagesDidLoad(TaskResult { try await subscriptionClient.getAvailablePackages() }))
        }

      case let .availablePackagesDidLoad(result):
        state.availablePackages = result.toProgressiveResult()
        return .none

      case let .purchasePackage(package):
        state.purchaseProgress = .inProgress
        return .run { send in
          await send(.purchaseCompleted(TaskResult { try await subscriptionClient.purchase(package) }))
        }

      case let .purchaseCompleted(result):
        state.purchaseProgress = result.toProgressiveResult()
        return .none

      case .termsOfUseTapped:
        state.termsOverlay = .termsOfUse
        return .none

      case .subscrtiptionTermsTapped:
        state.termsOverlay = .subscriptionTerms
        return .none

      case .privacyPolicyTapped:
        state.termsOverlay = .privacyPolicy
        return .none

      case .restorePurchasesTapped:
        return .run { send in
          await send(.restorePurchaseCompleted(TaskResult { try await subscriptionClient.restore() }))
        }

      case let .restorePurchaseCompleted(.success(isSubscribed)):
        state.isSubscribed = isSubscribed
        if !isSubscribed {
          state.alert = .init(
            title: .init("No Purchases Found"),
            message: .init("We couldn't find any purchases associated with your account."),
            dismissButton: .default(.init("OK"))
          )
        }
        return .none

      case let .restorePurchaseCompleted(.failure(error)):
        state.alert = .error(error)
        return .none

      case let .showAlert(alert):
        state.alert = alert
        return .none

      case .alert:
        return .none

      case .termsOverlay:
        return .none
      }
    }
    .onChange(of: \.availablePackages.errorValue?.equatable) { _, newValue in
      Reduce { state, _ in
        if let newValue {
          state.alert = .error(newValue)
        }
        return .none
      }
    }
    .onChange(of: \.purchaseProgress.errorValue?.equatable) { _, newValue in
      Reduce { state, _ in
        if let newValue {
          state.alert = .error(newValue)
        }
        return .none
      }
    }
  }
}

// MARK: - SubscriptionDetailsView

struct SubscriptionDetailsView: View {
  @ObserveInjection var inject

  let store: StoreOf<SubscriptionDetails>
  @ObservedObject var viewStore: ViewStoreOf<SubscriptionDetails>

  init(store: StoreOf<SubscriptionDetails>) {
    self.store = store
    viewStore = ViewStoreOf<SubscriptionDetails>(store, observe: { $0 }, removeDuplicates: ==)
  }

  var body: some View {
    ZStack {
      Color.DS.Background.primary.ignoresSafeArea()

      VStack(spacing: .grid(4)) {
        WhisperBoardKitAsset.subscriptionHeader.swiftUIImage
          .resizable()
          .scaledToFit()

        Spacer()

        VStack(spacing: .grid(6)) {
          HStack(spacing: .grid(1)) {
            Text("WhisperBoard")
              .font(.DS.title)

            Text("PRO")
              .font(.DS.badge)
              .padding(.horizontal, 3)
              .padding(.vertical, 1)
              .background {
                RoundedRectangle(cornerRadius: .grid(1))
                  .fill(Color.DS.Text.accent)
              }
          }
          .accessibilityElement(children: .combine)

          FeatureView(
            icon: "doc.text.below.ecg",
            title: "Fast Cloud Transcription",
            description: "Using large v2 whisper model."
          )
          //          FeatureView(
          //            icon: "speaker.wave.2",
          //            title: "Voice Generation",
          //            description: "Generate audio from final transcription using user's voice."
          //          )
          FeatureView(
            icon: "ellipsis.message",
            title: "AI text processing",
            description: "Edit transcription using AI."
          )
          FeatureView(
            icon: "star.circle.fill",
            title: "More Pro Features",
            description: "And more to come!"
          )
        }
        .frame(maxWidth: .infinity)

        Spacer()

        if viewStore.availablePackages.isInProgress {
          ProgressView()
            .progressViewStyle(.circular)
            .padding(.top, .grid(4))
        } else if let package = viewStore.availablePackages.successValue?.first {
          Text(package.localizedDescription)
            .textStyle(.label)

          Text("Only " + (package.localizedIntroductoryPriceString ?? package.localizedPriceString))
            .textStyle(.label)

          Button {
            viewStore.send(.purchasePackage(id: package.id))
          } label: {
            Text("Subscribe")
              .font(.DS.titleBold)
          }
          .primaryButtonStyle()
        } else {
          Text("Error loading packages")
            .textStyle(.navigationTitle)
        }

        HStack {
          Button(action: { viewStore.send(.privacyPolicyTapped) }) {
            Text("Privacy Policy")
          }

          Button(action: { viewStore.send(.termsOfUseTapped) }) {
            Text("Terms of Use")
          }

          Button("Restore Purchases") {
            viewStore.send(.restorePurchasesTapped)
          }
        }
      }
      .padding(.horizontal, .grid(8))
      .padding(.bottom, .grid(4))
      .frame(maxHeight: .infinity, alignment: .bottom)
    }
    .alert(store: store.scope(state: \.$alert, action: SubscriptionDetails.Action.alert))
    .task { viewStore.send(.onTask) }
    .enableInjection()
  }
}

// MARK: - FeatureView

struct FeatureView: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(alignment: .top, spacing: .grid(4)) {
      Image(systemName: icon)
        .resizable()
        .foregroundStyle(Color.DS.Text.accent)
        .scaledToFit()
        .frame(width: 25, height: 25)
        .padding(.top, .grid(1))

      VStack(alignment: .leading, spacing: 0) {
        Text(title)
          .textStyle(.label)

        Text(description)
          .textStyle(.sublabel)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
    }
  }
}

#if DEBUG
  struct SubscriptionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
      SubscriptionDetailsView(
        store: Store(
          initialState: SubscriptionDetails.State(),
          reducer: { SubscriptionDetails() }
        )
      )
      .previewAllPresets()
    }
  }
#endif
