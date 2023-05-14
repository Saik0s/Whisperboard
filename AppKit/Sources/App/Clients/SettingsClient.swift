import AppDevUtils
import Combine
import ComposableArchitecture
import Dependencies
import Foundation

// MARK: - SettingsClient

struct SettingsClient {
  /// Returns a publisher that emits the current settings.
  ///
  /// - note: The publisher is a function that can be called to get a fresh publisher instance.
  /// - returns: A publisher that emits a `Settings` value or an `Error` if the settings cannot be retrieved.
  var settingsPublisher: @Sendable () -> AnyPublisher<Settings, Error>
  /// A property that returns a `Settings` value.
  ///
  /// - note: This property is marked with the `@Sendable` attribute, which means it can be safely used across concurrency
  /// domains.
  ///
  /// - returns: A `Settings` value that represents the current configuration of the app.
  var settings: @Sendable () -> Settings
  /// Updates the app settings asynchronously.
  ///
  /// - parameter settings: The new settings to apply.
  /// - throws: An error if the update fails.
  /// - note: This function is marked with `@Sendable` to indicate that it can be safely called from any actor or task.
  var updateSettings: @Sendable (Settings) async throws -> Void
}

extension SettingsClient {
  /// Sets a new value for a given key path of the settings object and updates the settings asynchronously.
  ///
  /// - parameter value: The new value to be assigned to the key path.
  /// - parameter keyPath: The writable key path of the settings object that identifies the property to be updated.
  /// - throws: An error if the update operation fails.
  func setValue<Value: Codable>(_ value: Value, forKey keyPath: WritableKeyPath<Settings, Value>) async throws {
    var settings = settings()
    settings[keyPath: keyPath] = value
    try await updateSettings(settings)
  }
}

// MARK: DependencyKey

/// A type that manages the app settings using a JSON file.
///
/// This type provides a singleton instance that can read and write the settings from a JSON file in the document
/// directory using a `CodableValueSubject`. It also exposes a publisher, a getter, and a setter for the settings. If
/// the JSON file does not exist, it creates one with default values.
extension SettingsClient: DependencyKey {
  /// Returns a singleton instance of `Self` that manages the app settings.
  ///
  /// - The instance uses a `CodableValueSubject` to read and write the settings from a JSON file in the document
  /// directory.
  /// - The instance provides a publisher, a getter, and a setter for the settings.
  /// - The instance creates the JSON file if it does not exist.
  /// - returns: A `Self` object with the appropriate methods and properties.
  static var liveValue: Self = {
    let docURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let settingsURL = docURL.appendingPathComponent("settings.json")
    if FileManager.default.fileExists(atPath: settingsURL.path) == false {
      let settings = Settings()
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try! encoder.encode(settings)
      try! data.write(to: settingsURL)
    }
    let settingsSubject = CodableValueSubject<Settings>(fileURL: settingsURL)

    return Self(
      settingsPublisher: { settingsSubject.eraseToAnyPublisher() },
      settings: { settingsSubject.value ?? Settings() },
      updateSettings: { settings in settingsSubject.send(settings) }
    )
  }()
}

extension DependencyValues {
  /// A computed property that accesses or updates the `SettingsClient` instance associated with the receiver.
  ///
  /// - get: Returns the `SettingsClient` instance stored in the receiver's storage.
  /// - set: Stores a new `SettingsClient` instance in the receiver's storage.
  var settings: SettingsClient {
    get { self[SettingsClient.self] }
    set { self[SettingsClient.self] = newValue }
  }
}
