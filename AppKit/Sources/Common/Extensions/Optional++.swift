import Foundation

// MARK: - WrappedOptionalProtocol

protocol WrappedOptionalProtocol {
  associatedtype Wrapped
}

// MARK: - OptionalProtocol

protocol OptionalProtocol {
  var isSome: Bool { get }

  func unwrap() -> Any
}

extension Optional {
  var describing: String {
    switch self {
    case let .some(value):
      return "\(value)"
    case .none:
      return "nil"
    }
  }

  func doIfSome(_ block: (Wrapped) -> Void) {
    if case let .some(wrapped) = self {
      block(wrapped)
    }
  }

  func replacingNil(with value: Wrapped) -> Wrapped {
    guard case let .some(wrapped) = self else {
      return value
    }

    return wrapped
  }

  var isSome: Bool {
    switch self {
    case .none:
      return false

    case .some:
      return true
    }
  }

  func unwrap() -> Any {
    switch self {
    case .none:
      preconditionFailure("nil unwrap")

    case let .some(unwrapped):
      return unwrapped
    }
  }
}

extension Optional {
  struct RequireError: Error, CustomStringConvertible {
    let function: StaticString
    let file: StaticString
    let line: UInt
    let column: UInt
    let message: String

    init(function: StaticString, file: StaticString, line: UInt, column: UInt, message: String) {
      self.function = function
      self.file = file
      self.line = line
      self.column = column
      self.message = message
    }

    var description: String {
      "\(URL(fileURLWithPath: "\(file)").lastPathComponent):\(line) \(function) Required optional value was nil. \(message)"
    }
  }

  func require(orThrowError: Error,
               function _: StaticString = #function,
               file _: StaticString = #file,
               line _: UInt = #line,
               column _: UInt = #column) throws -> Wrapped {
    if let value = self as Wrapped? {
      return value
    }

    throw orThrowError
  }

  func require(orThrow errorClosure: (() -> Error)? = nil,
               function: StaticString = #function,
               file: StaticString = #file,
               line: UInt = #line,
               column: UInt = #column) throws -> Wrapped {
    if let value = self as Wrapped? {
      return value
    }

    throw errorClosure?() ?? RequireError(function: function, file: file, line: line, column: column, message: "")
  }

  func require(message: String,
               function: StaticString = #function,
               file: StaticString = #file,
               line: UInt = #line,
               column: UInt = #column) throws -> Wrapped {
    if let value = self as Wrapped? {
      return value
    }

    throw RequireError(function: function, file: file, line: line, column: column, message: message)
  }

  func required(function: StaticString = #function, file: StaticString = #file, line: UInt = #line, column: UInt = #column) -> Wrapped {
    if let value = self as Wrapped? {
      return value
    }

    fatalError(RequireError(function: function, file: file, line: line, column: column, message: "").description)
  }
}

extension Optional where Wrapped: Collection {
  var isEmptyOrNil: Bool {
    self?.isEmpty ?? true
  }
}

// MARK: - Optional + WrappedOptionalProtocol

extension Optional: WrappedOptionalProtocol {}

// MARK: - Optional + OptionalProtocol

extension Optional: OptionalProtocol {}

precedencegroup OptionalAssignment { associativity: right }

infix operator ?=: OptionalAssignment

extension Optional {
  static func ?= (variable: inout Wrapped, value: Self) {
    if let value {
      variable = value
    }
  }
}
