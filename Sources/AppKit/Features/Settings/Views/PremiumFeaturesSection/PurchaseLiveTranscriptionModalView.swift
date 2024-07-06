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
            Text("Transform Your Audio Experience with Live Transcription")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Instant. Accurate. Revolutionary.")
                .font(.title2)
                .fontWeight(.medium)

            HStack(spacing: 2) {
                ForEach(0 ..< 5) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }

            Text("Elevate your productivity, enhance accessibility, and unlock new possibilities in communication. Experience the future of audio transcription today.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Join thousands of satisfied users!")
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - FeatureListView

struct FeatureListView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            FeatureItemView(icon: "waveform", text: "Instant Speech-to-Text Conversion")
            FeatureItemView(icon: "globe", text: "Support for Multiple Languages")
            FeatureItemView(icon: "brain", text: "Advanced AI-driven Accuracy")
            FeatureItemView(icon: "bolt.fill", text: "Ultra-fast Processing Speed")
            FeatureItemView(icon: "person.2.fill", text: "Intelligent Speaker Recognition")
            FeatureItemView(icon: "doc.text.fill", text: "Real-time Editable Transcripts")
            FeatureItemView(icon: "icloud.fill", text: "Effortless Cloud Synchronization")
            FeatureItemView(icon: "lock.shield.fill", text: "Robust Privacy Protection")
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
