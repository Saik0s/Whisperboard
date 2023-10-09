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
  case noPackageInOffering
  case cancelled
  case noTransaction

  var errorDescription: String? {
    switch self {
    case .noCurrentOffering:
      return "No current offering available."
    case .noPackageInOffering:
      return "No package in the current offering."
    case .cancelled:
      return "The transaction was cancelled."
    case .noTransaction:
      return "No transaction found."
    }
  }
}

// MARK: - SubscriptionClient + DependencyKey

extension SubscriptionClient: DependencyKey {
  static let liveValue: SubscriptionClient = .init(
    configure: { userID in
      Purchases.configure(withAPIKey: Secrets.REVENUECAT_API_KEY, appUserID: userID)
    },
    checkIfSubscribed: {
      let customerInfo = try await Purchases.shared.customerInfo()
      return customerInfo.entitlements[Secrets.STORE_ENTITLEMENT_ID]?.isActive == true
    },
    isSubscribedStream: {
      Purchases.shared.customerInfoStream
        .map {
          $0.entitlements[Secrets.STORE_ENTITLEMENT_ID]?.isActive == true
        }
        .eraseToStream()
    },
    purchase: { packageID in
      guard let offering = try await Purchases.shared.offerings().current else {
        throw SubscriptionClientError.noCurrentOffering
      }

      guard let package = offering.package(identifier: packageID) else {
        throw SubscriptionClientError.noPackageInOffering
      }

      let (transaction, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
      guard !userCancelled else {
        throw SubscriptionClientError.cancelled
      }

      guard let transaction, let skTransaction = transaction.sk2Transaction else {
        throw SubscriptionClientError.noTransaction
      }

      await transaction.sk2Transaction?.finish()

      @Dependency(\.keychainClient) var keychainClient
      keychainClient.transactionID = transaction.transactionIdentifier

      return SubscriptionTransaction(
        id: transaction.transactionIdentifier,
        date: transaction.purchaseDate,
        dataRepresentation: skTransaction.jsonRepresentation
      )
    },
    restore: {
      let customerInfo = try await Purchases.shared.restorePurchases()
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
}

// MARK: - Dependencies

extension DependencyValues {
  var subscriptionClient: SubscriptionClient {
    get { self[SubscriptionClient.self] }
    set { self[SubscriptionClient.self] = newValue }
  }
}
