import ComposableArchitecture
import Foundation

// MARK: - ProgressiveResult

enum ProgressiveResult<Value, Progress> {
  case none
  case inProgress(Progress)
  case success(Value)
  case error(EquatableError)
}

extension ProgressiveResult where Progress == Void {
  static var inProgress: Self {
    .inProgress(())
  }
}

extension ProgressiveResult {
  static func failure(_ error: Error) -> ProgressiveResult {
    ProgressiveResult.error(error.equatable)
  }
}

extension ProgressiveResult {
  var successValue: Value? {
    guard case let .success(value) = self else { return nil }
    return value
  }

  var progressValue: Progress? {
    guard case let .inProgress(progress) = self else { return nil }
    return progress
  }

  var errorValue: Error? {
    guard case let .error(error) = self else { return nil }
    return error
  }
}

extension ProgressiveResult where Value: Equatable {
  static func == (lhs: Self, rhs: Value) -> Bool where Progress == Void {
    switch (lhs, rhs) {
    case let (.success(lhsValue), rhsValue):
      return lhsValue == rhsValue

    default:
      return false
    }
  }
}

// MARK: Equatable

extension ProgressiveResult: Equatable where Value: Equatable {
  static func == (lhs: ProgressiveResult<Value, Progress>, rhs: ProgressiveResult<Value, Progress>) -> Bool {
    isEqual(lhs: lhs, rhs: rhs)
  }

  static func == (lhs: Self, rhs: Self) -> Bool where Progress: Equatable {
    switch (lhs, rhs) {
    case let (.inProgress(lhsValue), .inProgress(rhsValue)):
      return lhsValue == rhsValue

    default:
      return isEqual(lhs: lhs, rhs: rhs)
    }
  }

  private static func isEqual(lhs: ProgressiveResult<Value, Progress>, rhs: ProgressiveResult<Value, Progress>) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none):
      true

    case (.inProgress, .inProgress):
      true

    case let (.success(lhsValue), .success(rhsValue)):
      lhsValue == rhsValue

    case let (.error(lhsError), .error(rhsError)):
      lhsError == rhsError

    default:
      false
    }
  }
}

// MARK: Hashable

extension ProgressiveResult: Hashable where Value: Hashable {
  func hash(into hasher: inout Hasher) {
    calculateHash(hasher: &hasher)
  }

  func hash(into hasher: inout Hasher) where Progress: Hashable {
    calculateHash(hasher: &hasher)
    switch self {
    case let .inProgress(progress):
      hasher.combine(progress)

    default:
      break
    }
  }

  private func calculateHash(hasher: inout Hasher) {
    switch self {
    case .none:
      hasher.combine(0)

    case .inProgress:
      hasher.combine(1)

    case let .success(value):
      hasher.combine(2)
      hasher.combine(value)

    case let .error(error):
      hasher.combine(3)
      hasher.combine(error)
    }
  }
}

typealias ProgressiveResultOf<Value> = ProgressiveResult<Value, Void>

extension ProgressiveResult {
  var isNone: Bool {
    guard case .none = self else { return false }
    return true
  }

  var isInProgress: Bool {
    guard case .inProgress = self else { return false }
    return true
  }

  var isSuccess: Bool {
    guard case .success = self else { return false }
    return true
  }

  var isError: Bool {
    guard case .error = self else { return false }
    return true
  }

  var isFinished: Bool {
    isSuccess || isError
  }
}

extension TaskResult {
  func toProgressiveResult<Progress>() -> ProgressiveResult<Success, Progress> {
    switch self {
    case let .success(value):
      .success(value)

    case let .failure(error):
      .failure(error)
    }
  }

  var asProgressiveResult: ProgressiveResultOf<Success> {
    switch self {
    case let .success(value):
      .success(value)

    case let .failure(error):
      .failure(error)
    }
  }
}
