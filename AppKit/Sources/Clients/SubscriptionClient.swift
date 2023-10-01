import Dependencies
import Foundation
import IdentifiedCollections
import RevenueCat

// MARK: - SubscriptionPackageType

enum SubscriptionPackageType {
  case monthly, yearly, lifetime
}

// MARK: - SubscriptionPackage

struct SubscriptionPackage: Identifiable, Hashable {
  let id: String
  let packageType: PackageType
  let localizedTitle: String
  let localizedDescription: String
  let localizedPriceString: String
  let localizedIntroductoryPriceString: String?
}

// MARK: - SubscriptionTransaction

struct SubscriptionTransaction: Identifiable, Hashable {
  let id: String
  let date: Date
  let dataRepresentation: Data
}

// MARK: - SubscriptionClient

struct SubscriptionClient {
  var configure: @Sendable (_ userID: String) -> Void
  var checkIfSubscribed: @Sendable () async throws -> Bool
  var isSubscribedStream: @Sendable () -> AsyncStream<Bool>
  var purchase: @Sendable (_ packageID: SubscriptionPackage.ID) async throws -> SubscriptionTransaction
  var restore: @Sendable () async throws -> Bool
  var getAvailablePackages: @Sendable () async throws -> IdentifiedArrayOf<SubscriptionPackage>
}

// MARK: - SubscriptionClientError

enum SubscriptionClientError: Error {
  case noCurrentOffering
  case cancelled
  case noTransaction
}

// MARK: - SubscriptionClient + DependencyKey

extension SubscriptionClient: DependencyKey {
  static let liveValue = {
    let delegate = PurchasesDelegateHandler()

    return SubscriptionClient(
      configure: { userID in
        Purchases.configure(withAPIKey: Secrets.REVENUECAT_API_KEY, appUserID: userID)
        Purchases.shared.delegate = delegate
      },
      checkIfSubscribed: {
        let customerInfo = try await Purchases.shared.customerInfo()
        delegate.customerInfo = customerInfo
        return customerInfo.entitlements[Secrets.STORE_ENTITLEMENT_ID]?.isActive == true
      },
      isSubscribedStream: {
        delegate.$customerInfo
          .map { $0?.entitlements[Secrets.STORE_ENTITLEMENT_ID]?.isActive == true }
          .values
          .eraseToStream()
      },
      purchase: { packageID in
        guard let offering = delegate.offerings?.current else {
          throw SubscriptionClientError.noCurrentOffering
        }

        guard let package = offering.package(identifier: packageID) else {
          throw SubscriptionClientError.noCurrentOffering
        }

        let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
        delegate.customerInfo = customerInfo
        guard !userCancelled else { throw SubscriptionClientError.cancelled }
        await transaction?.sk2Transaction?.finish()
        guard let transaction, let skTransaction = transaction.sk2Transaction else { throw SubscriptionClientError.noTransaction }
        return SubscriptionTransaction(
          id: transaction.transactionIdentifier,
          date: transaction.purchaseDate,
          dataRepresentation: skTransaction.jsonRepresentation
        )
      },
      restore: {
        let customerInfo = try await Purchases.shared.restorePurchases()
        delegate.customerInfo = customerInfo
        return customerInfo.entitlements[Secrets.STORE_ENTITLEMENT_ID]?.isActive == true
      },
      getAvailablePackages: {
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else {
          throw SubscriptionClientError.noCurrentOffering
        }

        return current.availablePackages
          .map { package in
            SubscriptionPackage(
              id: package.identifier,
              packageType: package.packageType,
              localizedTitle: package.storeProduct.localizedTitle,
              localizedDescription: package.storeProduct.localizedDescription,
              localizedPriceString: package.localizedPriceString,
              localizedIntroductoryPriceString: package.localizedIntroductoryPriceString
            )
          }
          .identifiedArray
      }
    )
  }()
}

// MARK: - Dependencies

extension DependencyValues {
  var subscriptionClient: SubscriptionClient {
    get { self[SubscriptionClient.self] }
    set { self[SubscriptionClient.self] = newValue }
  }
}

// MARK: - PurchasesDelegateHandler

private final class PurchasesDelegateHandler: NSObject {
  @Published var customerInfo: CustomerInfo?
  @Published var offerings: Offerings? = nil
  @Published var subscriptionActive: Bool = false
}

// MARK: PurchasesDelegate

extension PurchasesDelegateHandler: PurchasesDelegate {
  func purchases(_: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    updateCustomerInfo(customerInfo)
  }

  func purchases(_: Purchases, readyForPromotedProduct _: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
    startPurchase { [weak self] _, info, error, cancelled in
      if let info, error == nil, !cancelled {
        self?.updateCustomerInfo(info)
      }
    }
  }

  private func updateCustomerInfo(_ customerInfo: CustomerInfo) {
    self.customerInfo = customerInfo
    subscriptionActive = customerInfo.entitlements[Secrets.STORE_ENTITLEMENT_ID]?.isActive == true
  }
}
