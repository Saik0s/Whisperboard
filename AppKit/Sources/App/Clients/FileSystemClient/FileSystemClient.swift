import Dependencies
import Foundation
import AppDevUtils

// MARK: - FileSystemClient

struct FileSystemClient {
  var getDocumentDirectoryURL: @Sendable () -> URL
  var getSettingsFileURL: @Sendable () -> URL
  var getRecordingsFileURL: @Sendable () -> URL
}

extension DependencyValues {
  var fileSystem: FileSystemClient {
    get { self[FileSystemClient.self] }
    set { self[FileSystemClient.self] = newValue }
  }
}

// MARK: - FileSystemClient + DependencyKey

extension FileSystemClient: DependencyKey {
  static var liveValue: Self = {
    @Dependency(\.dataMigrator) var dataMigrator: DataMigrator
    dataMigrator.migrate()

    let docURL: URL
    do {
      docURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    } catch {
      log.error("Could not get documents directory", error)
      docURL = URL(fileURLWithPath: "~/Documents")
    }
    let settingsURL = docURL.appendingPathComponent("settings.json")
    let recordingsURL = docURL.appendingPathComponent("recordings.json")

    return Self(
      getDocumentDirectoryURL: { docURL },
      getSettingsFileURL: { settingsURL },
      getRecordingsFileURL: { recordingsURL }
    )
  }()
}
