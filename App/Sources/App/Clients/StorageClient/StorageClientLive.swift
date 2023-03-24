import AppDevUtils
import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation

// MARK: - StorageClient + DependencyKey

extension StorageClient: DependencyKey {
  static let liveValue: Self = {
    let storage = Storage()
    let documentsURL = (try? storage.documentsURL()) ?? URL(fileURLWithPath: "~/Documents")

    return Self(
      read: {
        try await storage.read().identifiedArray
      },
      write: { recordings in
        try await storage.write(recordings.elements)
      },
      createNewWhisperURL: {
        let filename = UUID().uuidString + ".wav"
        let url = documentsURL.appending(path: filename)
        return url
      },
      audioFileURLWithName: { name in
        documentsURL.appending(path: name)
      },
      waveFileURLWithName: { name in
        documentsURL.appending(path: name)
      },
      delete: { recording in
        let url = documentsURL.appending(path: recording.fileName)
        try FileManager.default.removeItem(at: url)
      }
    )
  }()
}

// MARK: - Storage

private final class Storage {
  func documentsURL() throws -> URL {
    try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
  }

  func dbURL() throws -> URL {
    try documentsURL().appendingPathComponent("recordings.json")
  }

  func read() async throws -> [RecordingInfo] {
    let docURL = try documentsURL()
    let dbURL = try dbURL()

    // If the database file does not exist, create an empty array and save it to the file
    if !FileManager.default.fileExists(atPath: dbURL.path) {
      try [RecordingInfo]().saveToFile(path: dbURL.path)
    }

    // Get the recordings stored in the database file
    let storedRecordings = try [RecordingInfo].fromFile(path: dbURL.path)
    // Get the files in the documents directory with the .wav extension
    let recordingFiles = try FileManager.default
      .contentsOfDirectory(atPath: docURL.path)
      .filter { $0.hasSuffix(".wav") }

    // Initialize a flag to track if the database file should be written to
    var shouldWrite = false
    var recordings: [RecordingInfo] = try recordingFiles.map { file in
      // If the recording is already stored in the database, return it
      if let recording = storedRecordings.first(where: { $0.fileName == file }) {
        return recording
      }

      // Otherwise, set the flag to true and create the recording info
      shouldWrite = true
      return try createInfo(fileName: file)
    }

    // Sort the recordings by date
    recordings.sort { info, info2 in
      info.date > info2.date
    }

    // If the flag is true, write the recordings to the database file
    if shouldWrite {
      try recordings.saveToFile(path: dbURL.path)
    }

    return recordings
  }

  func write(_ recordings: [RecordingInfo]) async throws {
    let docURL = try documentsURL()
    let dbURL = try dbURL()

    let existing = recordings.filter { whisper in
      FileManager.default.fileExists(atPath: docURL.appending(path: whisper.fileName).path)
    }

    try existing.saveToFile(path: dbURL.path)
  }

  private func getFileDuration(url: URL) throws -> TimeInterval {
    let audioPlayer = try AVAudioPlayer(contentsOf: url)
    return audioPlayer.duration
  }

  private func createInfo(fileName: String) throws -> RecordingInfo {
    let docURL = try documentsURL()
    let fileURL = docURL.appending(component: fileName)
    // let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    // let date = attributes[.creationDate] as? Date ?? Date()
    let date = Date()
    let duration = try getFileDuration(url: fileURL)
    let recording = RecordingInfo(fileName: fileName, date: date, duration: duration)
    return recording
  }
}
