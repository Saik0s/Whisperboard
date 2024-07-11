import ComposableArchitecture

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<[RecordingInfo]>> {
  static var recordings: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "recordings.json")), [])
  }
}

public extension PersistenceReaderKey where Self == PersistenceKeyDefault<InMemoryKey<[TranscriptionTask]>> {
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
