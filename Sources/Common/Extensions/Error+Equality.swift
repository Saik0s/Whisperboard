import Foundation

// MARK: - EquatableError

public struct EquatableError: Error, Equatable, Hashable {
  private let _base: Error
  private let _message: String

  public init(_ base: Error) {
    _base = base
    _message = String(describing: base)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs._message == rhs._message
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(_message)
  }
}

public extension Error {
  var equatable: EquatableError {
    EquatableError(self)
  }
}

public extension Error {
  static var unknown: EquatableError {
    NSError(domain: "Unknown", code: 0, userInfo: nil).equatable
  }
}
