import Common
import ComposableArchitecture
import StoreKit
import SwiftUI

// MARK: - PurchaseLiveTranscriptionModal

@Reducer
struct PurchaseLiveTranscriptionModal {
  @ObservableState
  struct State: Equatable {
    @Shared(.premiumFeatures) var premiumFeatures
    var isPurchasing = false
    var errorMessage: String?
    var productPrice: String?
    var isLoading = true
    var restoreProgress: ProgressiveResultOf<Bool> = .none
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: Equatable {
    case onTask
    case didFetchProduct(TaskResult<String>)
    case purchaseButtonTapped
    case purchaseResult(TaskResult<Bool>)
    case delegate(Delegate)
    case restorePurchasesTapped
    case restorePurchaseCompleted(TaskResult<Bool>)
    case termsOfUseTapped
    case privacyPolicyTapped
    case alert(PresentationAction<Alert>)

    enum Delegate: Equatable {
      case didFinishTransaction
    }

    enum Alert: Equatable {}
  }

  // MARK: - PurchaseError

  enum PurchaseError: Error, LocalizedError {
    case productNotFound
    case unverifiedTransaction
    case userCancelled
    case transactionPending
    case unknownError

    var errorDescription: String? {
      switch self {
      case .productNotFound:
        "The product could not be found. Please try again later."
      case .unverifiedTransaction:
        "The transaction could not be verified. Please contact support."
      case .userCancelled:
        "The purchase was cancelled."
      case .transactionPending:
        "The transaction is pending. Please check your payment method and try again."
      case .unknownError:
        "An unknown error occurred. Please try again later."
      }
    }
  }

  @Dependency(\.openURL) var openURL: OpenURLEffect
  @Dependency(\.build) var build: BuildClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onTask:
        state.isLoading = true
        state.errorMessage = nil
        return .run { send in
          await send(.didFetchProduct(TaskResult { try await fetchPrice() }))
        }

      case let .didFetchProduct(.success(price)):
        state.isLoading = false
        state.productPrice = price
        return .none

      case let .didFetchProduct(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        return .none

      case .purchaseButtonTapped:
        state.isPurchasing = true
        state.errorMessage = nil
        return .run { send in
          await send(.purchaseResult(TaskResult { try await purchase() }))
        }

      case let .purchaseResult(.success(isEnabled)):
        state.isPurchasing = false
        state.premiumFeatures.liveTranscriptionIsPurchased = isEnabled
        return .send(.delegate(.didFinishTransaction))

      case let .purchaseResult(.failure(error)):
        state.isPurchasing = false
        state.errorMessage = error.localizedDescription
        state.premiumFeatures.liveTranscriptionIsPurchased = false
        return .none

      case .delegate(.didFinishTransaction):
        return .none

      case .restorePurchasesTapped:
        state.restoreProgress = .inProgress
        return .run { send in
          await send(.restorePurchaseCompleted(TaskResult { try await restorePurchases() }))
        }

      case let .restorePurchaseCompleted(.success(isSubscribed)):
        state.restoreProgress = .success(isSubscribed)
        if !isSubscribed {
          state.alert = .init(
            title: .init("No Purchases Found"),
            message: .init("We couldn't find any purchases associated with your account."),
            dismissButton: .default(.init("OK"))
          )
        } else {
          state.premiumFeatures.liveTranscriptionIsPurchased = true
          return .send(.delegate(.didFinishTransaction))
        }
        return .none

      case let .restorePurchaseCompleted(.failure(error)):
        state.restoreProgress = .failure(error)
        state.alert = .error(error)
        return .none

      case .termsOfUseTapped:
        return .run { _ in
          await openURL(build.termsOfServiceURL())
        }

      case .privacyPolicyTapped:
        return .run { _ in
          await openURL(build.privacyPolicyURL())
        }

      case .alert:
        return .none
      }
    }
    .ifLet(\.alert, action: \.alert)
  }

  func fetchPrice() async throws -> String {
    let products = try await Product.products(for: [PremiumFeaturesProductID.liveTranscription])
    guard let product = products.first else {
      throw PurchaseError.productNotFound
    }
    return product.displayPrice
  }

  func purchase() async throws -> Bool {
    let products = try await Product.products(for: [PremiumFeaturesProductID.liveTranscription])
    guard let product = products.first else {
      throw PurchaseError.productNotFound
    }

    logs.info("Attempting to purchase product: \(product.id)")
    let result = try await product.purchase()
    logs.info("Purchase result: \(result)")

    switch result {
    case let .success(verification):
      logs.info("Purchase successful, verification: \(verification)")
      switch verification {
      case let .verified(transaction):
        await transaction.finish()
        return true

      case .unverified:
        throw PurchaseError.unverifiedTransaction
      }

    case .userCancelled:
      return false

    case .pending:
      throw PurchaseError.transactionPending

    @unknown default:
      throw PurchaseError.unknownError
    }
  }

  func restorePurchases() async throws -> Bool {
    for await result in Transaction.currentEntitlements {
      if case let .verified(transaction) = result {
        if transaction.productID == PremiumFeaturesProductID.liveTranscription {
          await transaction.finish()
          return true
        }
      }
    }
    return false
  }
}

// MARK: - PurchaseLiveTranscriptionModalView

struct PurchaseLiveTranscriptionModalView: View {
  @Perception.Bindable var store: StoreOf<PurchaseLiveTranscriptionModal>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(8)) {
        HeaderView()
        FeatureListView()

        if store.isLoading {
          ProgressView()
        } else if let errorMessage = store.errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
            .font(.caption)
        } else if let productPrice = store.productPrice {
          PurchaseButton(
            isPurchasing: store.isPurchasing,
            productPrice: productPrice,
            action: { store.send(.purchaseButtonTapped) }
          )

          if store.restoreProgress.isNone || store.restoreProgress.isError {
            Button { store.send(.restorePurchasesTapped) } label: {
              Text("Restore Purchases")
                .foregroundColor(.DS.Text.accent)
                .font(.DS.body)
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
      }
      .padding(.grid(6))
      .task { await store.send(.onTask).finish() }
      .alert($store.scope(state: \.alert, action: \.alert))
    }
  }
}

// MARK: - HeaderView

struct HeaderView: View {
  var body: some View {
    VStack(spacing: 16) {
      Text("Speak, and Watch Your Words Appear")
        .font(.largeTitle)
        .fontWeight(.bold)
        .multilineTextAlignment(.center)

      Text("Instant, Accurate Speech-to-Text")
        .font(.title2)
        .fontWeight(.semibold)

      HStack(spacing: 2) {
        ForEach(0 ..< 5) { _ in
          Image(systemName: "star.fill")
            .foregroundColor(.yellow)
        }
      }

      Text("Transform meetings, lectures, and ideas into text instantly. Never miss a word, thought, or brilliant idea again.")
        .font(.body)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      Text("Ready to 10x Your Productivity?")
        .font(.headline)
        .foregroundColor(.DS.Text.accentAlt)
        .shadow(color: .DS.Text.accentAlt.opacity(0.5), radius: 10, x: 0, y: 0)
    }
  }
}

// MARK: - FeatureListView

struct FeatureListView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Label {
        VStack(alignment: .leading) {
          Text("Instant Transcription")
          Text("See your words as you speak")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      } icon: {
        Image(systemName: "waveform")
      }

      Label {
        VStack(alignment: .leading) {
          Text("Multiple Languages")
          Text("Switch between languages effortlessly")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      } icon: {
        Image(systemName: "globe")
      }

      Label {
        VStack(alignment: .leading) {
          Text("AI-Powered Accuracy")
          Text("Enjoy precise transcriptions, even with accents")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      } icon: {
        Image(systemName: "brain")
      }

      Label {
        VStack(alignment: .leading) {
          Text("100% Private")
          Text("Your words stay on your device, always")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      } icon: {
        Image(systemName: "lock.shield.fill")
      }
    }
  }
}

// MARK: - PurchaseButton

struct PurchaseButton: View {
  let isPurchasing: Bool
  let productPrice: String?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      if isPurchasing {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .white))
          .frame(width: 50, height: 50)
      } else {
        Text(productPrice.map { "Start Transcribing Now - Just \($0)" } ?? "Start Transcribing Now")
          .font(.headline)
          .foregroundColor(.white)
          .frame(height: 50)
          .frame(maxWidth: .infinity)
      }
    }
    .background {
      Color.DS.Background.accent
        .cornerRadius(10)
        .shadow(color: .DS.Background.accent.opacity(0.5), radius: 10, x: 0, y: 0)
    }
    .disabled(isPurchasing)
  }
}
