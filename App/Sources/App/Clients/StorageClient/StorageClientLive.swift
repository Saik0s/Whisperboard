import AppDevUtils
import AVFoundation
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import UIKit

// MARK: - StorageClient + DependencyKey

extension StorageClient: DependencyKey {
  static let liveValue: Self = {
    let storage = Storage()
    let documentsURL = (try? Storage.documentsURL()) ?? URL(fileURLWithPath: "~/Documents")

    return Self(
      read: {
        storage.currentRecordingsSubject.value.identifiedArray
      },

      recordingsInfoStream: storage.currentRecordingsSubject.replaceError(with: []).eraseToAnyPublisher(),

      write: { recordings in
        storage.write(recordings.elements)
      },

      addRecordingInfo: { recording in
        let newRecordings = (storage.currentRecordingsSubject.value) + [recording]
        storage.write(newRecordings)
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

      delete: { recordingId in
        let recordings = storage.currentRecordingsSubject.value
        guard let recording = recordings.identifiedArray[id: recordingId] else {
          return
        }

        let url = documentsURL.appending(path: recording.fileName)
        try FileManager.default.removeItem(at: url)
        let newRecordings = recordings.filter { $0.id != recordingId }
        storage.write(newRecordings)

      },

      update: { id, updater in
        var recordings = storage.currentRecordingsSubject.value.identifiedArray
        guard var recording = recordings[id: id] else {
          customAssertionFailure()
          return
        }

        updater(&recording)

        recordings[id: id] = recording
        storage.write(recordings.elements)
      }
    )
  }()
}

// MARK: - Storage

private final class Storage {
  let currentRecordingsSubject: CurrentValueSubject<[RecordingInfo], Never>

  private let cancellable: AnyCancellable

  init() {
    let subject = CurrentValueSubject<[RecordingInfo], Never>([])
    cancellable = subject.dropFirst().sink { recordings in
      do {
        let fileURL = try Self.dbURL()
        try recordings.write(toFile: fileURL, encoder: JSONEncoder())
      } catch {
        customAssertionFailure()
        log.error(error)
      }
    }
    currentRecordingsSubject = subject

    do {
      try currentRecordingsSubject.send(read())
    } catch {
      customAssertionFailure()
      log.error(error)
    }

    subscribeToDidBecomeActiveNotifications()
  }

  static func documentsURL() throws -> URL {
    try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
  }

  static func dbURL() throws -> URL {
    try documentsURL().appendingPathComponent("recordings.json")
  }

  func containerGroupURL() -> URL? {
    let appGroupName = "group.whisperboard"
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)?.appending(component: "share")
  }

  func read() throws -> [RecordingInfo] {
    let docURL = try Self.documentsURL()
    let dbURL = try Self.dbURL()

    // If the database file does not exist, create an empty array and save it to the file
    if !FileManager.default.fileExists(atPath: dbURL.path) {
      log.verbose("Database file does not exist, creating new database file")
      try [RecordingInfo]().saveToFile(path: dbURL.path)
    }

    // Get the recordings stored in the database file
    var storedRecordings = try [RecordingInfo].fromFile(path: dbURL.path)

    // If there are files in shared container, move them to the documents directory
    let sharedRecordings = moveSharedFiles(to: docURL)
    storedRecordings.append(contentsOf: sharedRecordings)

    // Get the files in the documents directory with the .wav extension
    let recordingFiles = try FileManager.default.contentsOfDirectory(atPath: docURL.path).filter { $0.hasSuffix(".wav") }

    // Initialize a flag to track if the database file should be written to
    var shouldWrite = false
    var recordings: [RecordingInfo] = try recordingFiles.map { file in
      // If the recording is already stored in the database, return it
      if let recording = storedRecordings.first(where: { $0.fileName == file }) {
        return recording
      }

      // Otherwise, set the flag to true and create the recording info
      shouldWrite = true
      log.verbose("Recording \(file) not found in database, creating new info for it")
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

  func write(_ recordings: [RecordingInfo]) {
    currentRecordingsSubject.send(recordings)
  }

  private func moveSharedFiles(to docURL: URL) -> [RecordingInfo] {
    var recordings: [RecordingInfo] = []
    if let containerGroupURL = containerGroupURL(), FileManager.default.fileExists(atPath: containerGroupURL.path) {
      do {
        for file in try FileManager.default.contentsOfDirectory(atPath: containerGroupURL.path) {
          let sourceURL = containerGroupURL.appendingPathComponent(file)
          let newFileName = UUID().uuidString + ".wav"
          let destinationURL = docURL.appending(path: newFileName)
          try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
          let duration = try getFileDuration(url: destinationURL)
          let recording = RecordingInfo(
            fileName: newFileName,
            title: sourceURL.deletingPathExtension().lastPathComponent,
            date: Date(),
            duration: duration
          )
          recordings.append(recording)
          log.info("successfully moved file \(file) to \(destinationURL.path)")
          log.info(recording)
        }
      } catch {
        log.error(error)
      }
    }
    return recordings
  }

  private func createInfo(fileName: String) throws -> RecordingInfo {
    let docURL = try Storage.documentsURL()
    let fileURL = docURL.appending(component: fileName)
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let date = attributes[.creationDate] as? Date ?? Date()
    let duration = try getFileDuration(url: fileURL)
    let recording = RecordingInfo(fileName: fileName, date: date, duration: duration)
    return recording
  }

  private func subscribeToDidBecomeActiveNotifications() {
    NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
      guard let self else { return }
      do {
        let recordings = try self.read()
        self.write(recordings)
      } catch {
        log.error(error)
      }
    }
  }
}

// MARK: - CodableValueSubject + Then

extension CodableValueSubject: Then {}
