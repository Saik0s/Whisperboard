import Foundation

public struct ErrorMessage: Error {
  let message: String

  public init(_ message: String) {
    self.message = message
  }

  public var localizedDescription: String {
    message
  }

  public var errorDescription: String? {
    message
  }
}