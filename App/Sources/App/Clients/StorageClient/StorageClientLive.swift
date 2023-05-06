import AppDevUtils
import AVFoundation
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import UIKit
import SwiftUI

// MARK: - StorageClient + DependencyKey

extension StorageClient: DependencyKey {
  static let liveValue: Self = {
    let storage = Storage()
    let documentsURL = Storage.documentsURL

    return Self(
      read: {
        storage.currentRecordings.identifiedArray
      },

      recordingsInfoStream: storage.currentRecordingsStream,

      write: { recordings in
        storage.write(recordings.elements)
      },

      addRecordingInfo: { recording in
        let newRecordings = storage.currentRecordings + [recording]
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
        let recordings = storage.currentRecordings.identifiedArray
        guard let recording = recordings[id: recordingId] else {
          customAssertionFailure()
          return
        }

        let url = documentsURL.appending(path: recording.fileName)
        try FileManager.default.removeItem(at: url)
        let newRecordings = recordings.filter { $0.id != recordingId }
        storage.write(newRecordings.elements)
      },

      update: { id, updater in
        var recordings = storage.currentRecordings.identifiedArray
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

private final class Storage: ObservableObject {
  @Published private var recordings: [RecordingInfo] = []

  static var documentsURL: URL {
    do {
      return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    } catch {
      customAssertionFailure("Could not get documents directory")
      return URL(fileURLWithPath: "~/Documents")
    }
  }

  static var dbURL: URL {
    documentsURL.appendingPathComponent("recordings.json")
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

  init() {
    recordings = (try? [RecordingInfo].fromFile(path: Self.dbURL.path)) ?? []

    subscribeToDidBecomeActiveNotifications()
    catchingRead()
  }

  func read() throws {
    var storedRecordings = currentRecordings

    // If there are files in shared container, move them to the documents directory
    let sharedRecordings = moveSharedFiles(to: Self.documentsURL)
    if !sharedRecordings.isEmpty {
      storedRecordings.append(contentsOf: sharedRecordings)
    }

    // Get the files in the documents directory with the .wav extension
    let recordingFiles = try FileManager.default
      .contentsOfDirectory(atPath: Self.documentsURL.path)
      .filter { $0.hasSuffix(".wav") }

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

    recordings = newRecordings.sorted { $0.date > $1.date }

    do {
      try recordings.saveToFile(path: Self.dbURL.path)
    } catch {
      log.error(error)
    }
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

// MARK: - CodableValueSubject + Then

extension CodableValueSubject: Then {}
