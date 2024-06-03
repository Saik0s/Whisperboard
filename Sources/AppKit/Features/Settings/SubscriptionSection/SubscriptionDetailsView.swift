import Common
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - SubscriptionDetails

@Reducer
struct SubscriptionDetails {
  @ObservableState
  struct State: Equatable {
    var purchaseProgress: ProgressiveResultOf<Bool> = .none
    var restoreProgress: ProgressiveResultOf<Bool> = .none
    var availablePackage: ProgressiveResultOf<SubscriptionPackage> = .none

    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: Equatable {
    case onTask

    case availablePackagesDidLoad(TaskResult<IdentifiedArrayOf<SubscriptionPackage>>)
    case purchasePackage(id: SubscriptionPackage.ID)
    case purchaseCompleted(TaskResult<Bool>)
    case restorePurchaseCompleted(TaskResult<Bool>)

    case termsOfUseTapped
    case privacyPolicyTapped
    case restorePurchasesTapped

    case alert(PresentationAction<Alert>)

    case showAlert(AlertState<Self.Alert>)

    enum Alert: Equatable {}
  }

  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient
  @Dependency(\.openURL) var openURL: OpenURLEffect
  @Dependency(\.build) var build: BuildClient
  @Dependency(\.dismiss) var dismiss

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onTask:
        state.availablePackage = .inProgress
        return .run { send in
          await send(.availablePackagesDidLoad(TaskResult { try await subscriptionClient.getAvailablePackages() }))
        }

      case let .availablePackagesDidLoad(.success(packages)):
        guard let package = packages.first(where: { $0.packageType == .monthly }) else {
          enum AvailablePackageError: Error { case cantFindMonthlyPackage }

          state.availablePackage = .failure(AvailablePackageError.cantFindMonthlyPackage)
          return .none
        }
        withAnimation {
          state.availablePackage = .success(package)
        }
        return .none

      case let .availablePackagesDidLoad(.failure(error)):
        state.availablePackage = .failure(error)
        return .none

      case let .purchasePackage(package):
        withAnimation {
          state.purchaseProgress = .inProgress
        }
        return .run { send in
          await send(.purchaseCompleted(TaskResult { try await subscriptionClient.purchase(package) }))
        }

      case let .purchaseCompleted(.success(value)):
        withAnimation {
          state.purchaseProgress = .success(value)
        }
        return .run { _ in
          await dismiss()
        }

      case let .purchaseCompleted(.failure(error)):
        withAnimation {
          switch error {
          case SubscriptionClientError.cancelled:
            state.purchaseProgress = .none

          default:
            state.purchaseProgress = .failure(error)
            state.alert = .error(error)
          }
        }
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
        withAnimation {
          state.restoreProgress = .inProgress
        }
        return .run { send in
          await send(.restorePurchaseCompleted(TaskResult { try await subscriptionClient.restore() }))
        }

      case let .restorePurchaseCompleted(.success(isSubscribed)):
        withAnimation {
          state.restoreProgress = .success(isSubscribed)
        }
        if !isSubscribed {
          state.alert = .init(
            title: .init("No Purchases Found"),
            message: .init("We couldn't find any purchases associated with your account."),
            dismissButton: .default(.init("OK"))
          )
          return .none
        } else {
          return .run { _ in
            await dismiss()
          }
        }

      case let .restorePurchaseCompleted(.failure(error)):
        withAnimation {
          state.restoreProgress = .failure(error)
        }
        state.alert = .error(error)
        return .none

      case let .showAlert(alert):
        state.alert = alert
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.alert, action: \.alert)
  }
}

// MARK: - SubscriptionDetailsView

struct SubscriptionDetailsView: View {
  @Environment(\.dismiss) var dismiss

  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<SubscriptionDetails>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(4)) {
        WhisperBoardKitAsset.subscriptionHeader.swiftUIImage
          .resizable()
          .scaledToFit()
          .shining(
            animation: .easeInOut(duration: 3).delay(7).repeatForever(autoreverses: false),
            gradient: .init(colors: [.black.opacity(0.5), .black, .black.opacity(0.5)])
          )

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

        VStack(spacing: .grid(4)) {
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
        }
        .padding(.top, .grid(4))

        Spacer()

        VStack(spacing: .grid(4)) {
          switch store.availablePackage {
          case .inProgress, .none:
            ProgressView()
              .progressViewStyle(.circular)
              .padding(.vertical, .grid(4))

          case .error:
            Text("Error loading packages")
              .textStyle(.error)
              .padding(.vertical, .grid(4))

          case let .success(package):
            if store.purchaseProgress.isInProgress || store.restoreProgress.isInProgress {
              ProgressView()
                .progressViewStyle(.circular)
                .padding(.vertical, .grid(8))
            } else if store.purchaseProgress.isNone || store.purchaseProgress.isError {
              Text("3 days free, then ")
                .font(.DS.body)
                .foregroundColor(.DS.Text.base)
                +
                Text(package.localizedPriceString)
                .font(.DS.bodyBold)
                .foregroundColor(.DS.Text.base)
                +
                Text("/month.")
                .font(.DS.body)
                .foregroundColor(.DS.Text.base)

              Button {
                store.send(.purchasePackage(id: package.id))
              } label: {
                Text("Try It Free")
                  .font(WhisperBoardKitFontFamily.Poppins.semiBold.swiftUIFont(size: 24))
                  .foregroundColor(.DS.Text.base)
                  .frame(maxWidth: .infinity)
              }
              .primaryButtonStyle()
              .transition(.scale)
            }
          }

          if store.restoreProgress.isNone || store.restoreProgress.isError {
            Button { store.send(.restorePurchasesTapped) } label: {
              Text("Restore Purchases")
                .foregroundColor(.DS.Text.accent)
                .font(.DS.body)
            }
          }
        }

        HStack {
          Button(action: { store.send(.privacyPolicyTapped) }) {
            Text("Privacy Policy")
              .foregroundColor(.DS.Text.subdued)
              .textStyle(.captionBase)
          }

          Text("•")
            .foregroundColor(.DS.Text.subdued)
            .textStyle(.captionBase)

          Button(action: { store.send(.termsOfUseTapped) }) {
            Text("Terms of Use")
              .foregroundColor(.DS.Text.subdued)
              .textStyle(.captionBase)
          }
        }
      }
      .padding(.grid(4))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.DS.Background.primary)
      .overlay(alignment: .topTrailing) {
        Button { dismiss() } label: {
          Image(systemName: "x.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 30))
            .foregroundColor(.DS.Text.base)
            .padding(.grid(4))
        }
      }
      .alert($store.scope(state: \.alert, action: \.alert))
      .task { store.send(.onTask) }
    }
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

      VStack(alignment: .leading, spacing: .grid(1)) {
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
