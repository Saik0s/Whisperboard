import Foundation
import ComposableArchitecture

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<IdentifiedArrayOf<RecordingInfo>>> {
  static var recordings: Self {
    let fileURL = FileManager.default
          .urls(for: .documentDirectory, in: .userDomainMask)
          .first!
          .appendingPathComponent("recordings.json")

    var fallbackValue: IdentifiedArrayOf<RecordingInfo> = []

    if FileManager.default.fileExists(atPath: fileURL.path) {
      do {
        let data = try Data(contentsOf: fileURL)
        fallbackValue = try JSONDecoder().decode(IdentifiedArrayOf<RecordingInfo>.self, from: data)
      } catch {
        try? FileManager.default.removeItem(at: fileURL)
      }
    }

    return PersistenceKeyDefault(
      .fileStorage(fileURL),
      fallbackValue
    )
  }
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<InMemoryKey<IdentifiedArrayOf<TranscriptionTask>>> {
  static var transcriptionTasks: Self {
    PersistenceKeyDefault(.inMemory(#function), [])
  }
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<InMemoryKey<Bool>> {
  static var isICloudSyncInProgress: Self {
    PersistenceKeyDefault(.inMemory(#function), false)
  }
}

public extension PersistenceReaderKey where Self == FileStorageKey<Settings> {
  static var settings: Self {
    .fileStorage(.documentsDirectory.appending(component: "settings.json"))
  }
}
