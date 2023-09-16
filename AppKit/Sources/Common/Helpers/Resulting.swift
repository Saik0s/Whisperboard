func resulting<T>(_ closure: () throws -> T) -> Result<T, Error> {
  do {
    return try .success(closure())
  } catch {
    return .failure(error)
  }
}

extension Result where Success == String, Failure: Error {
  var stringify: String {
    switch self {
    case let .success(value):
      return value
    case let .failure(error):
      return "Error: " + error.localizedDescription
    }
  }
}
