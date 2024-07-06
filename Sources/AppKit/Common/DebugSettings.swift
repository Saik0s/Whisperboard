import ComposableArchitecture

// MARK: - DebugSettings

public struct DebugSettings: Codable, Hashable {
  public var shouldOverridePurchaseStatus = false
  public var liveTranscriptionIsPurchasedOverride = false
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<DebugSettings>> {
  static var debugSettings: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "debugSettings.json")), DebugSettings())
  }
}
