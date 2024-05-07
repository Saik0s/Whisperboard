import Foundation

// MARK: - EquatableError

struct EquatableError: Error, Equatable, Hashable {
  private let _base: Error
  private let _message: String

  init(_ base: Error) {
    _base = base
    _message = String(describing: base)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs._message == rhs._message
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(_message)
  }
}

extension Error {
  var equatable: EquatableError {
    EquatableError(self)
  }
}

extension Error {
  static var unknown: EquatableError {
    NSError(domain: "Unknown", code: 0, userInfo: nil).equatable
  }
}
