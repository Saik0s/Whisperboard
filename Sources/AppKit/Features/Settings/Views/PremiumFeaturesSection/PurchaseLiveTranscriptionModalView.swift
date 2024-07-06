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
            Text("Revolutionize Your World with Live Transcription")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("It's not just amazing. It's magical.")
                .font(.title2)
                .fontWeight(.medium)

            HStack(spacing: 2) {
                ForEach(0 ..< 5) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }

            Text("This changes everything. The way we communicate, the way we work, the way we live. It's a quantum leap in human interaction.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("- Steve Jobs")
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - FeatureListView

struct FeatureListView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            FeatureItemView(icon: "waveform", text: "Real-time Speech-to-Text")
            FeatureItemView(icon: "globe", text: "Multi-language Support")
            FeatureItemView(icon: "brain", text: "AI-powered Accuracy")
            FeatureItemView(icon: "bolt.fill", text: "Lightning-fast Processing")
            FeatureItemView(icon: "person.2.fill", text: "Speaker Identification")
            FeatureItemView(icon: "doc.text.fill", text: "Instant Editable Transcripts")
            FeatureItemView(icon: "icloud.fill", text: "Seamless Cloud Integration")
            FeatureItemView(icon: "lock.shield.fill", text: "Privacy-first Design")
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
                Text("Unlock Live Transcription")
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
