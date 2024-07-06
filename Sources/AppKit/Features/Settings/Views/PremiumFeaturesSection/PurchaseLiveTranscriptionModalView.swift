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

    enum PurchaseError: Error {
        case productNotFound
        case unverifiedTransaction
        case userCancelled
        case transactionPending
        case unknown
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
        VStack(spacing: 10) {
            Text("Speak, See, Succeed!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Your words, instantly visible.")
                .font(.title2)
                .fontWeight(.medium)

            HStack(spacing: 2) {
                ForEach(0 ..< 5) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }

            Text("Boost your productivity, make communication a breeze, and never miss a word. Welcome to the future of speech-to-text!")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Join the speech revolution!")
                .font(.headline)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - FeatureListView

struct FeatureListView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            FeatureItemView(icon: "waveform", text: "Instant voice-to-text magic")
            FeatureItemView(icon: "globe", text: "Speak in multiple languages")
            FeatureItemView(icon: "brain", text: "AI-powered accuracy")
            FeatureItemView(icon: "bolt.fill", text: "Lightning-fast processing")
            FeatureItemView(icon: "person.2.fill", text: "Smart speaker identification")
            FeatureItemView(icon: "doc.text.fill", text: "Edit transcripts on the fly")
            FeatureItemView(icon: "icloud.fill", text: "Sync across all your devices")
            FeatureItemView(icon: "lock.shield.fill", text: "Your words stay private")
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isPurchasing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Start Speaking, Start Seeing!")
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
