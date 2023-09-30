import Foundation

func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
  (lhs as? any Equatable)?.isEqual(other: rhs)
}

private extension Equatable {
  func isEqual(other: Any) -> Bool {
    self == other as? Self
  }
}
