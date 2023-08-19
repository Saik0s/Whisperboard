import AppDevUtils
import Combine
import Dependencies
import Foundation
import UIKit

final class Storage {
  @Published private var recordings: [RecordingInfo] = []

  static var documentsURL: URL {
    @Dependency(\.fileSystem) var fileSystem: FileSystemClient
    return fileSystem.getDocumentDirectoryURL()
  }

  static var dbURL: URL {
    @Dependency(\.fileSystem) var fileSystem: FileSystemClient
    return fileSystem.getRecordingsFileURL()
  }

  static var containerGroupURL: URL? {
    let appGroupName = "group.whisperboard"
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)?.appending(component: "share")
  }

  var currentRecordings: [RecordingInfo] {
    recordings
  }

  var currentRecordingsStream: AnyPublisher<[RecordingInfo], Never> {
    $recordings.eraseToAnyPublisher()
  }

  private var currentlyRecordingURL: URL?

  init() {
    recordings = (try? [RecordingInfo].fromFile(path: Self.dbURL.path)) ?? []

    subscribeToDidBecomeActiveNotifications()
    catchingRead()
  }

  func read() throws {
    var storedRecordings = currentRecordings

    // Update the duration of the recordings that don't have it
    storedRecordings = storedRecordings.map { recording in
      var recording = recording
      if recording.duration == 0 {
        do {
          recording.duration = try getFileDuration(url: Self.documentsURL.appending(path: recording.fileName))
        } catch {
          log.error(error)
        }
      }
      return recording
    }

    // If there are files in shared container, move them to the documents directory
    let sharedRecordings = moveSharedFiles(to: Self.documentsURL)
    if !sharedRecordings.isEmpty {
      storedRecordings.append(contentsOf: sharedRecordings)
    }

    // Get the files in the documents directory with the .wav extension
    let recordingFiles = try FileManager.default
      .contentsOfDirectory(atPath: Self.documentsURL.path)
      .filter { $0.hasSuffix(".wav") }
      // Remove the currently recording file from the list until it is finished
      .filter { $0 != currentlyRecordingURL?.lastPathComponent }

    let recordings: [RecordingInfo] = try recordingFiles.map { file in
      // If the recording is already stored in the database, return it
      if let recording = storedRecordings.first(where: { $0.fileName == file }) {
        return recording
      }

      log.warning("Recording \(file) not found in database, creating new info for it")
      return try createInfo(fileName: file)
    }

    write(recordings)
  }

  func write(_ newRecordings: [RecordingInfo]) {
    log.verbose("Writing \(newRecordings.count) recordings to database file")

    // If the currently recording file is in the new recordings, set it to nil as it is not in progress anymore
    if newRecordings.contains(where: { $0.fileName == currentlyRecordingURL?.lastPathComponent }) {
      currentlyRecordingURL = nil
    }

    recordings = newRecordings.sorted { $0.date > $1.date }

    do {
      try recordings.saveToFile(path: Self.dbURL.path)
    } catch {
      log.error(error)
    }
  }

  func setAsCurrentlyRecording(_ url: URL) {
    currentlyRecordingURL = url
  }

  private func moveSharedFiles(to docURL: URL) -> [RecordingInfo] {
    var recordings: [RecordingInfo] = []
    if let containerGroupURL = Self.containerGroupURL, FileManager.default.fileExists(atPath: containerGroupURL.path) {
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
    let docURL = Storage.documentsURL
    let fileURL = docURL.appending(component: fileName)
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let date = attributes[.creationDate] as? Date ?? Date()
    let duration = try getFileDuration(url: fileURL)
    let recording = RecordingInfo(fileName: fileName, date: date, duration: duration)
    return recording
  }

  private func subscribeToDidBecomeActiveNotifications() {
    NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
      self?.catchingRead()
    }
  }

  private func catchingRead() {
    do {
      try read()
    } catch {
      log.error("Error reading recordings: \(error)")
    }
  }
}
