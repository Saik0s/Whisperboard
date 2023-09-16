import Foundation

// MARK: - Private helpers

extension DateFormatter {
  static func withDateFormat(_ format: String) -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    return dateFormatter
  }
}
