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
    }

    enum Action: Equatable {
        case purchaseButtonTapped
        case purchaseResult(TaskResult<Bool>)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didFinishTransaction
        }
    }

    // MARK: - PurchaseError

    enum PurchaseError: Error, LocalizedError {
        case productNotFound
        case unverifiedTransaction
        case userCancelled
        case transactionPending
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "The product could not be found. Please try again later."
            case .unverifiedTransaction:
                return "The transaction could not be verified. Please contact support."
            case .userCancelled:
                return "The purchase was cancelled."
            case .transactionPending:
                return "The transaction is pending. Please check your payment method and try again."
            case .unknown:
                return "An unknown error occurred. Please try again later."
            }
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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
            }
        }
    }

    func purchase() async throws -> Bool {
        let productID = "me.igortarasenko.Whisperboard.liveTranscription"

        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw PurchaseError.productNotFound
        }

        // Store the product price
        self.state.productPrice = product.displayPrice

        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            switch verification {
            case let .verified(transaction):
                await transaction.finish()
                return true

            case .unverified:
                throw PurchaseError.unverifiedTransaction
            }

        case .userCancelled:
            throw PurchaseError.userCancelled

        case .pending:
            throw PurchaseError.transactionPending

        @unknown default:
            // throw PurchaseError.unknown
            break
        }
      
      return false
    }
}

// MARK: - PurchaseLiveTranscriptionModalView

struct PurchaseLiveTranscriptionModalView: View {
    @Perception.Bindable var store: StoreOf<PurchaseLiveTranscriptionModal>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 20) {
                HeaderView()
                FeatureListView()
                PurchaseButton(
                    isPurchasing: store.isPurchasing,
                    productPrice: store.productPrice,
                    action: { store.send(.purchaseButtonTapped) }
                )
                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
        }
    }
}

// MARK: - HeaderView

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Talk. Type. Transform.")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Instant speech-to-text magic!")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 2) {
                ForEach(0 ..< 5) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }

            Text("Supercharge your productivity. Simplify communication. Capture every word. Experience the future of voice-to-text!")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Ready to revolutionize your speech?")
                .font(.headline)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - FeatureListView

struct FeatureListView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            FeatureItemView(icon: "waveform", text: "Instant speech-to-text")
            FeatureItemView(icon: "globe", text: "Multilingual support")
            FeatureItemView(icon: "brain", text: "AI-driven precision")
            FeatureItemView(icon: "bolt.fill", text: "Rapid processing")
            FeatureItemView(icon: "person.2.fill", text: "Smart voice recognition")
            FeatureItemView(icon: "doc.text.fill", text: "Real-time editing")
            FeatureItemView(icon: "icloud.fill", text: "Cross-device sync")
            FeatureItemView(icon: "lock.shield.fill", text: "Privacy guaranteed")
        }
    }
}

// MARK: - FeatureItemView

struct FeatureItemView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(text)
                .font(.body)
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
            } else {
                Text(productPrice.map { "Unleash Your Voice Now! (\($0))" } ?? "Unleash Your Voice Now!")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(Color.blue)
        .cornerRadius(10)
        .disabled(isPurchasing)
    }
}
