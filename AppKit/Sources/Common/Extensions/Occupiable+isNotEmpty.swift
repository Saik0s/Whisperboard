import protocol AudioKit.Occupiable
import IdentifiedCollections

// MARK: - IdentifiedArray + Occupiable

extension IdentifiedArray: Occupiable {}

/// Extend the idea of occupiability to optionals. Specifically, optionals wrapping occupiable things.
extension Optional where Wrapped: Occupiable {
  var isNilOrEmpty: Bool {
    switch self {
    case .none:
      return true

    case let .some(value):
      return value.isEmpty
    }
  }

  var isNotNilNotEmpty: Bool {
    !isNilOrEmpty
  }
}
