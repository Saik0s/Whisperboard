import AppDevUtils
import Combine
import ComposableArchitecture
import Dependencies
import Foundation

// MARK: - SettingsClient

struct SettingsClient {
  var settingsPublisher: @Sendable () -> AnyPublisher<Settings, Never>
  var getSettings: @Sendable () -> Settings
  var updateSettings: @Sendable (Settings) async throws -> Void
}

extension SettingsClient {
  func setValue<Value: Codable>(_ value: Value, forKey keyPath: WritableKeyPath<Settings, Value>) async throws {
    var settings = getSettings()
    settings[keyPath: keyPath] = value
    try await updateSettings(settings)
  }
}

// MARK: DependencyKey

extension SettingsClient: DependencyKey {
  static var liveValue: Self = {
    @Dependency(\.fileSystem) var fileSystem: FileSystemClient
    let settingsURL = fileSystem.getSettingsFileURL()
    let settings = (try? Settings.fromFile(path: settingsURL.path)) ?? Settings()
    let container = SettingsContainer(settings: settings)

    return Self(
      settingsPublisher: { container.$settings.eraseToAnyPublisher() },
      getSettings: { container.settings },
      updateSettings: { newSettings in
        guard newSettings != container.settings else { return }
        container.settings = newSettings
        try newSettings.saveToFile(path: settingsURL.path)
      }
    )
  }()
}

extension DependencyValues {
  var settings: SettingsClient {
    get { self[SettingsClient.self] }
    set { self[SettingsClient.self] = newValue }
  }
}

// MARK: - SettingsContainer

private final class SettingsContainer {
  @Published var settings: Settings

  init(settings: Settings) {
    self.settings = settings
  }
}
