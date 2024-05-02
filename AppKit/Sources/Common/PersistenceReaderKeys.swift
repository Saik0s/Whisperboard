import ComposableArchitecture

extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<[RecordingInfo]>> {
  static var recordings: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "recordings.json")), [])
  }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<[TranscriptionTask]>> {
  static var transcriptionTasks: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "tasks.json")), [])
  }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<FileStorageKey<Settings>> {
  static var settings: Self {
    PersistenceKeyDefault(.fileStorage(.documentsDirectory.appending(component: "settings.json")), .init())
  }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<InMemoryKey<Bool>> {
  static var isProcessing: Self {
    PersistenceKeyDefault(.inMemory("isProcessing"), false)
  }
}
