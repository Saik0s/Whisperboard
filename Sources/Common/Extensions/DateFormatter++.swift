import Foundation

// MARK: - Public helpers

public extension DateFormatter {
  static func withDateFormat(_ format: String) -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    return dateFormatter
  }
}
