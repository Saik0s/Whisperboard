import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - SubscriptionDetails

struct SubscriptionDetails: ReducerProtocol {
  struct State: Equatable {
    var purchaseProgress: ProgressiveResultOf<SubscriptionTransaction> = .none
    var availablePackages: ProgressiveResultOf<IdentifiedArrayOf<SubscriptionPackage>> = .none

    @PresentationState var alert: AlertState<Action.Alert>?

    var isSubscribed: Bool = false
  }

  enum Action: Equatable {
    case onTask

    case availablePackagesDidLoad(TaskResult<IdentifiedArrayOf<SubscriptionPackage>>)
    case purchasePackage(id: SubscriptionPackage.ID)
    case purchaseCompleted(TaskResult<SubscriptionTransaction>)
    case restorePurchaseCompleted(TaskResult<Bool>)

    case termsOfUseTapped
    case privacyPolicyTapped
    case restorePurchasesTapped

    case alert(PresentationAction<Alert>)

    case showAlert(AlertState<Action.Alert>)

    enum Alert: Equatable {}
  }

  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient
  @Dependency(\.openURL) var openURL: OpenURLEffect
  @Dependency(\.build) var build: BuildClient

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
        return .run { _ in
          await openURL(build.termsOfServiceURL())
        }

      case .privacyPolicyTapped:
        return .run { _ in
          await openURL(build.privacyPolicyURL())
        }

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
  @Environment(\.dismiss) var dismiss

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
        HStack(spacing: .grid(1)) {
          Text("WhisperBoard")
            .font(WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: 28))

          Text("PRO")
            .font(WhisperBoardKitFontFamily.Poppins.bold.swiftUIFont(size: 14))
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background {
              RoundedRectangle(cornerRadius: .grid(1))
                .fill(Color.DS.Text.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.top, .grid(8))

        Spacer()

        FeatureView(
          icon: "doc.text.below.ecg",
          title: "Fast Cloud Transcription",
          description: "Using large v2 whisper model."
        )
        FeatureView(
          icon: "ellipsis.message",
          title: "AI text processing",
          description: "Edit transcription using AI."
        )
        FeatureView(
          icon: "star.circle.fill",
          title: "More Pro Features",
          description: "All future pro features."
        )
        FeatureView(
          icon: "bolt.heart",
          title: "Support Development",
          description: "Help build the future of WhisperBoard."
        )

        Spacer()

        if viewStore.availablePackages.isInProgress {
          ProgressView()
            .progressViewStyle(.circular)
            .padding(.top, .grid(4))
        } else if let package = viewStore.availablePackages.successValue?.first {
          Text("2 weeks free, then ")
            .font(WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: 18))
            .foregroundColor(.DS.Text.base)
            +
            Text(package.localizedPriceString)
            .font(WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: 24))
            .foregroundColor(.DS.Text.base)
            +
            Text("/month.")
            .font(WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: 18))
            .foregroundColor(.DS.Text.base)

          Button {
            viewStore.send(.purchasePackage(id: package.id))
          } label: {
            Text("Try It Free")
              .font(WhisperBoardKitFontFamily.Poppins.bold.swiftUIFont(size: 24))
              .foregroundColor(.DS.Text.base)
              .frame(maxWidth: .infinity)
          }
          .primaryButtonStyle()
        } else {
          Text("Error loading packages")
            .textStyle(.navigationTitle)
        }

        Button { viewStore.send(.restorePurchasesTapped) } label: {
          Text("Restore Purchases")
            .foregroundColor(.DS.Text.accent)
            .font(.DS.body)
        }

        HStack {
          Button(action: { viewStore.send(.privacyPolicyTapped) }) {
            Text("Privacy Policy")
              .foregroundColor(.DS.Text.subdued)
              .textStyle(.captionBase)
          }

          Text("•")
            .foregroundColor(.DS.Text.subdued)
            .textStyle(.captionBase)

          Button(action: { viewStore.send(.termsOfUseTapped) }) {
            Text("Terms of Use")
              .foregroundColor(.DS.Text.subdued)
              .textStyle(.captionBase)
          }
        }
      }
      .padding(.horizontal, .grid(8))
      .overlay(alignment: .topTrailing) {
        Button { dismiss() } label: {
          Image(systemName: "x.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 30))
            .foregroundColor(.DS.Text.base)
            .padding(.grid(4))
        }
      }
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
        .foregroundStyle(Color.DS.accents05)
        .scaledToFit()
        .frame(width: 25, height: 25)
        .padding(.top, .grid(1))

      VStack(alignment: .leading, spacing: 0) {
        Text(title)
          .textStyle(.bodyBold)

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
