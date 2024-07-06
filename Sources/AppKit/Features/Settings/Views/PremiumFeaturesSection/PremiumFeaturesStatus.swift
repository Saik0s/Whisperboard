import ComposableArchitecture

// MARK: - PremiumFeaturesStatus

public struct PremiumFeaturesStatus: Codable, Hashable {
  public var liveTranscriptionIsPurchased: Bool? = nil
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<PremiumFeaturesStatus>> {
  static var premiumFeatures: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "premiumFeatures.json")), PremiumFeaturesStatus())
  }
}
