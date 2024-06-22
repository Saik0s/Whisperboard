import Foundation

// MARK: - Model

public struct Model: Identifiable, Hashable, Codable {
  public var id: String { name }
  public let name: String
  public let isLocal: Bool
  public let isDefault: Bool
  public let isDisabled: Bool

  public init(name: String, isLocal: Bool = false, isDefault: Bool = false, isDisabled: Bool = false) {
    self.name = name
    self.isLocal = isLocal
    self.isDefault = isDefault
    self.isDisabled = isDisabled
  }
}
