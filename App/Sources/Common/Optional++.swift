import Foundation

// MARK: - OptionalError

public enum OptionalError: Error {
  case requiredValueWasNil(file: StaticString, line: UInt, function: StaticString)

  var localizedDescription: String {
    switch self {
    case let .requiredValueWasNil(file, line, function):
      return "Required value was nil at \(file):\(line) \(function)"
    }
  }
}

public extension Optional {
  func require(_: @autoclosure () -> String = "Required value was nil",
               file: StaticString = #filePath,
               line: UInt = #line,
               function: StaticString = #function) throws -> Wrapped {
    guard let value = self else { throw OptionalError.requiredValueWasNil(file: file, line: line, function: function) }
    return value
  }
}
