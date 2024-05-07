import ComposableArchitecture
import Foundation
import KeychainAccess

// MARK: - KeychainClient

struct KeychainClient {
  var set: @Sendable (_ value: Data, _ key: String) throws -> Void
  var get: @Sendable (_ key: String) throws -> Data?
  var remove: @Sendable (_ key: String) throws -> Void
}

extension KeychainClient {
  func setString(_ value: String, for key: String) throws {
    try set(Data(value.utf8), key)
  }

  func getString(for key: String) throws -> String? {
    guard let data = try get(key) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

extension KeychainClient {
  var userID: String {
    let storedValue: String? = try? getString(for: #function)
    let uuidString: String = storedValue ?? UUID().uuidString
    if storedValue == nil {
      do {
        try setString(uuidString, for: #function)
      } catch {
        logs.error("Could not save user ID to keychain, error: \(error)")
      }
    }
    return uuidString
  }
}

// MARK: DependencyKey

extension KeychainClient: DependencyKey {
  static let liveValue: KeychainClient = {
    let keychain = Keychain()
    return KeychainClient(
      set: { value, key in try keychain.set(value, key: key) },
      get: { key in try keychain.getData(key) },
      remove: { key in try keychain.remove(key) }
    )
  }()
}

extension DependencyValues {
  var keychainClient: KeychainClient {
    get { self[KeychainClient.self] }
    set { self[KeychainClient.self] = newValue }
  }
}
