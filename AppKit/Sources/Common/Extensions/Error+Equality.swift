import Foundation

// MARK: - ErrorUtility

// https://kandelvijaya.com/2018/04/21/blog_equalityonerror/

class ErrorUtility {
  static func areEqual(_ lhs: Error, _ rhs: Error) -> Bool {
    lhs.reflectedString == rhs.reflectedString
  }
}

extension Error {
  var reflectedString: String {
    String(reflecting: self)
  }
}

// MARK: - EquatableError

@propertyWrapper
struct EquatableError: Equatable {
  typealias Value = Error

  var wrappedValue: Value

  init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }

  var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  static func == (lhs: EquatableError, rhs: EquatableError) -> Bool {
    ErrorUtility.areEqual(lhs.wrappedValue, rhs.wrappedValue)
  }
}

// MARK: - EquatableErrorWrapper

struct EquatableErrorWrapper: Equatable, Error, CustomStringConvertible {
  @EquatableError var error: Error

  init(error: Error) {
    self.error = error
  }
}

// MARK: CustomStringConvertible

extension EquatableErrorWrapper {
  var _domain: String { error._domain }
  var _code: Int { error._code }
  var _userInfo: AnyObject? { error._userInfo }
  func _getEmbeddedNSError() -> AnyObject? { error._getEmbeddedNSError() }

  var description: String {
    "\(error)"
  }

  var localizedDescription: String {
    error.localizedDescription
  }
}

extension Error {
  var equatable: EquatableErrorWrapper {
    EquatableErrorWrapper(error: self)
  }
}
