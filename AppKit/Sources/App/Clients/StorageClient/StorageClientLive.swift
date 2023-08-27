import AppDevUtils
import AVFoundation
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI
import UIKit

// MARK: - StorageError

enum StorageError: Error {
  case iCloudNotAvailable
}

// MARK: - StorageClient + DependencyKey

extension StorageClient: DependencyKey {
  static let liveValue: Self = {
    let storage = Storage()
    let documentsURL = Storage.documentsURL

    return StorageClient(
      read: {
        storage.currentRecordings.identifiedArray
      },

      recordingsInfoStream: storage.currentRecordingsStream.asAsyncStream(),

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
        storage.setAsCurrentlyRecording(url)
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
      },

      freeSpace: { freeDiskSpaceInBytes() },
      totalSpace: { totalDiskSpaceInBytes() },
      takenSpace: { takenSpace() },
      deleteStorage: { try await deleteStorage(storage) },
      uploadRecordingsToICloud: {
        log.verbose("iCloud Sync started")

        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
          log.error("Unable to access iCloud Account")
          log.error("Make sure you are signed in to iCloud and try again")
          throw StorageError.iCloudNotAvailable
        }

        try await Task(priority: .background) {
          var uploadedFiles: [String] {
            get { UserDefaults.standard.array(forKey: "uploadedFiles") as? [String] ?? [] }
            set { UserDefaults.standard.set(newValue, forKey: "uploadedFiles") }
          }

          uploadedFiles = []

          let fileManager = FileManager.default
          let cachesDirURL = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
          let tempDirURL = cachesDirURL.appending(path: "temp")
          try fileManager.createDirectory(at: tempDirURL, withIntermediateDirectories: true, attributes: nil)

          let dateFormater = DateFormatter().then { $0.dateFormat = "yyyy_MM_dd_HH_mm_ss" }
          for recording in storage.currentRecordings {
            let fileName = recording.fileName
            let readableFileName = (recording.title.isEmpty
              ? dateFormater.string(from: recording.date) + "_\(recording.id)"
              : recording.title) + ".wav"
            log.verbose("Uploading file: \(fileName), readable name: \(readableFileName)")
            let url = documentsURL.appending(path: fileName)
            let tempURL = tempDirURL.appending(path: "\(UUID().uuidString)_\(fileName)")
            let destination = iCloudURL.appending(path: readableFileName)

            if !uploadedFiles.contains(fileName) {
              log.verbose("Uploading file: \(fileName)")
              try fileManager.copyItem(at: url, to: tempURL)

              do {
                try fileManager.setUbiquitous(true, itemAt: tempURL, destinationURL: destination)
              } catch {
                log.error(error)
              }
              uploadedFiles.append(fileName)
            } else {
              log.verbose("File already uploaded: \(fileName)")
            }
          }
        }.value

        log.verbose("Finish updating ubiquity container")
      }
    )
  }()

  private static func totalDiskSpaceInBytes() -> UInt64 {
    do {
      let fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
      let capacity = values.volumeAvailableCapacityForImportantUsage
      return UInt64(capacity ?? 0)
    } catch {
      log.error("Error while getting total disk space: \(error)")
      return 0
    }
  }

  private static func freeDiskSpaceInBytes() -> UInt64 {
    do {
      let fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      let capacity = values.volumeAvailableCapacityForImportantUsage
      return UInt64(capacity ?? 0)
    } catch {
      log.error("Error while getting free disk space: \(error)")
      return 0
    }
  }

  private static func takenSpace() -> UInt64 {
    do {
      let fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let capacity = try fileURL.directoryTotalAllocatedSize(includingSubfolders: true)
      return UInt64(capacity ?? 0)
    } catch {
      log.error("Error while getting taken disk space: \(error)")
      return 0
    }
  }

  private static func deleteStorage(_ storage: Storage) async throws {
    let documentDir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let contents = try FileManager.default.contentsOfDirectory(at: documentDir, includingPropertiesForKeys: nil, options: [])
    for item in contents where item.lastPathComponent != "settings.json" {
      try FileManager.default.removeItem(at: item)
    }
    try storage.read()
  }
}

#if DEBUG
  extension StorageClient {
    /// In memory simple storage that is initialised with RecordingEnvelop.fixtures
    static var testValue: StorageClient {
      let recordings = CurrentValueSubject<[RecordingInfo], Never>(RecordingInfo.fixtures)

      return Self(
        read: {
          recordings.value.identifiedArray
        },

        recordingsInfoStream: recordings.asAsyncStream(),

        write: { newRecordings in
          recordings.value = newRecordings.elements
        },

        addRecordingInfo: { recording in
          recordings.value.append(recording)
        },

        createNewWhisperURL: {
          let filename = UUID().uuidString + ".wav"
          let url = URL(fileURLWithPath: filename)
          return url
        },

        audioFileURLWithName: { name in
          URL(fileURLWithPath: name)
        },

        waveFileURLWithName: { name in
          URL(fileURLWithPath: name)
        },

        delete: { recordingId in
          recordings.value = recordings.value.filter { $0.id != recordingId }
        },

        update: { id, updater in
          var identifiedRecordings = recordings.value.identifiedArray
          guard var recording = identifiedRecordings[id: id] else {
            customAssertionFailure()
            return
          }

          updater(&recording)

          identifiedRecordings[id: id] = recording

          recordings.value = identifiedRecordings.elements
        },

        freeSpace: { 0 },
        totalSpace: { 0 },
        takenSpace: { 0 },
        deleteStorage: {},
        uploadRecordingsToICloud: {}
      )
    }
  }
#endif
