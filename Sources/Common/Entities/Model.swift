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

public extension Model {
  static var mockModels: [Model] {
    [
      Model(name: "Model 1", isLocal: true, isDefault: true),
      Model(name: "Model 2", isLocal: true),
      Model(name: "Model 3", isLocal: true),
      Model(name: "Model 4", isLocal: true),
      Model(name: "Model 5", isLocal: true),
      Model(name: "Model 6", isLocal: true),
      Model(name: "Model 7", isLocal: true),
      Model(name: "Model 8", isLocal: true),
      Model(name: "Model 9", isLocal: true),
      Model(name: "Model 10", isLocal: true),
    ]
  }
}
