import Common
import Dependencies
import Foundation
import WhisperKit

// MARK: - Migration

protocol Migration {
  var version: Int { get }
  func migrate() throws
}

// MARK: - DataMigrator

class DataMigrator {
  private let migrations: [Migration]
  private var migrationVersion: Int {
    get { UserDefaults.standard.integer(forKey: "migrationVersion") }
    set { UserDefaults.standard.set(newValue, forKey: "migrationVersion") }
  }

  init(migrations: [Migration]) {
    self.migrations = migrations.sorted { $0.version < $1.version }
  }

  func migrate() {
    let currentVersion = migrationVersion

    for migration in migrations where migration.version > currentVersion {
      logs.info("Migrating to version \(migration.version) using \(type(of: migration))")
      do {
        try migration.migrate()
      } catch {
        logs.error("Migration failed: \(error)")
      }
      migrationVersion = migration.version
    }
  }
}

extension DependencyValues {
  var dataMigrator: DataMigrator {
    get { self[DataMigrator.self] }
    set { self[DataMigrator.self] = newValue }
  }
}

// MARK: - DataMigrator + DependencyKey

extension DataMigrator: DependencyKey {
  static var liveValue: DataMigrator {
    DataMigrator(migrations: [
      RecordingInfoMigration(),
      SettingsMigration(),
    ])
  }
}

// MARK: - RecordingInfoMigration

struct RecordingInfoMigration: Migration {
  var version: Int { 1 }

  func migrate() throws {
    struct OldRecordingInfo: Codable {
      var fileName: String
      var title = ""
      var date: Date
      var duration: TimeInterval
      var text: String = ""
      var isTranscribed = false
      var id: String { fileName }
    }

    let fileURL = try FileManager.default
      .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("recordings.json")
    let oldRecordings = try [OldRecordingInfo].fromFile(path: fileURL.path)

    let newRecordings = oldRecordings.map {
      RecordingInfo(
        fileName: $0.fileName,
        title: $0.title,
        date: $0.date,
        duration: $0.duration,
        editedText: nil,
        transcription: !$0.text.isEmpty
          ?
          Transcription(
            id: UUID(),
            fileName: $0.fileName,
            segments: [
              .init(
                startTime: 0,
                endTime: Int64($0.duration * 1000),
                text: $0.text,
                tokens: [],
                speaker: nil
              ),
            ],
            parameters: TranscriptionParameters(),
            model: "tiny",
            status: .done(Date(), .init())
          )
          : nil
      )
    }

    try newRecordings.saveToFile(at: fileURL)
  }
}

// MARK: - SettingsMigration

struct SettingsMigration: Migration {
  var version: Int { 2 }

  func migrate() throws {
    struct VoiceLanguage: Codable, Hashable, Identifiable {
      let id: Int32
      let code: String
      let name: String
      init(id: Int32, code: String) {
        self.id = id
        self.code = code
        name = Locale.current.localizedString(forLanguageCode: code) ?? code
      }

      static let auto = VoiceLanguage(id: -1, code: "auto")
    }

    struct OldSettings: Codable, Hashable {
      var voiceLanguage: VoiceLanguage = .auto
    }

    let settingsURL = try FileManager.default
      .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("settings.json")

    let oldSettings = try OldSettings.fromFile(path: settingsURL.path)

    let newSettings = Settings(
      useMockedClients: false,
      parameters: TranscriptionParameters(language: oldSettings.voiceLanguage.code)
    )
    try newSettings.saveToFile(at: settingsURL)
  }
}
