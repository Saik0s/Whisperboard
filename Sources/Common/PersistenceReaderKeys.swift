import ComposableArchitecture

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<[RecordingInfo]>> {
  static var recordings: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "recordings.json")), [])
  }
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<[TranscriptionTask]>> {
  static var transcriptionTasks: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "tasks.json")), [])
  }
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<Settings>> {
  static var settings: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "settings.json")), .init())
  }
}
