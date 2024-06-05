import Foundation

// MARK: - Models

public struct Model: Identifiable, Hashable, Codable {
  public var id: String { name }
  public let name: String
  public let description: String
  public let size: Int
  public let isRemote: Bool
  public let isLocal: Bool

  public init(name: String, description: String, size: Int = 0, isRemote: Bool = true, isLocal: Bool = false) {
    self.name = name
    self.description = description
    self.size = size
    self.isRemote = isRemote
    self.isLocal = isLocal
  }
}
