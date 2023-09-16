import Foundation

extension Result {
  var isFailure: Bool {
    guard case .failure = self else {
      return false
    }
    return true
  }

  var isSuccess: Bool {
    !isFailure
  }

  var value: Success? {
    guard case let .success(value) = self else {
      return nil
    }
    return value
  }

  var error: Failure? {
    guard case let .failure(error) = self else {
      return nil
    }
    return error
  }
}

extension Result {
  @discardableResult
  func onSuccess(_ handler: (Success) -> Void) -> Self {
    guard case let .success(value) = self else {
      return self
    }
    handler(value)
    return self
  }

  @discardableResult
  func onFailure(_ handler: (Failure) -> Void) -> Self {
    guard case let .failure(error) = self else {
      return self
    }
    handler(error)
    return self
  }
}
