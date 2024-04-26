import Dependencies
import Foundation

// MARK: - FileSystemClient

struct FileSystemClient {
  var getDocumentDirectoryURL: @Sendable () -> URL
  var getSettingsFileURL: @Sendable () -> URL
  var getRecordingsDBFileURL: @Sendable () -> URL
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
      logs.error("Could not get documents directory, error: \(error)")
      docURL = URL(fileURLWithPath: "~/Documents")
    }
    let settingsURL = docURL.appendingPathComponent("settings.json")
    let recordingsURL = docURL.appendingPathComponent("recordings.json")

    return FileSystemClient(
      getDocumentDirectoryURL: { docURL },
      getSettingsFileURL: { settingsURL },
      getRecordingsDBFileURL: { recordingsURL }
    )
  }()
}
