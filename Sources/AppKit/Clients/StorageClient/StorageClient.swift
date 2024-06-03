import AVFoundation
import Combine
import Common
import ComposableArchitecture
import Dependencies
import DependenciesAdditions
import Foundation
import SwiftUI
import UIKit
import XCTestDynamicOverlay

// MARK: - StorageError

enum StorageError: Error {
  case iCloudNotAvailable
}

// MARK: - StorageClient

@DependencyClient
struct StorageClient {
  var sync: @Sendable (_ recordings: [RecordingInfo]) async throws -> [RecordingInfo]
  var setCurrentRecordingURL: @Sendable (_ url: URL?) -> Void
  var freeSpace: @Sendable () -> UInt64 = { 0 }
  var totalSpace: @Sendable () -> UInt64 = { 0 }
  var takenSpace: @Sendable () -> UInt64 = { 0 }
  var deleteStorage: @Sendable () async throws -> Void
  var uploadRecordingsToICloud: @Sendable (_ reset: Bool, _ recordings: [RecordingInfo]) async throws -> Void
}

// MARK: DependencyKey

extension StorageClient: DependencyKey {
  static let liveValue: StorageClient = {
    let storage = Storage()

    return StorageClient(
      sync: { try await storage.sync(recordings: $0) },
      setCurrentRecordingURL: { storage.setAsCurrentlyRecording($0) },
      freeSpace: { freeDiskSpaceInBytes() },
      totalSpace: { totalDiskSpaceInBytes() },
      takenSpace: { takenSpace() },
      deleteStorage: { try await deleteStorage(storage) },
      uploadRecordingsToICloud: { reset, recordings in
        logs.info("iCloud Sync started")

        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
          logs.error("Unable to access iCloud Account")
          logs.error("Make sure you are signed in to iCloud and try again")
          throw StorageError.iCloudNotAvailable
        }

        await Task(priority: .background) {
          var uploadedFiles: [String] {
            get { UserDefaults.standard.array(forKey: "uploadedFiles") as? [String] ?? [] }
            set { UserDefaults.standard.set(newValue, forKey: "uploadedFiles") }
          }
          if reset {
            uploadedFiles = []
          }

          let fileManager = FileManager.default

          try? fileManager.createDirectory(at: iCloudURL, withIntermediateDirectories: true, attributes: nil)

          for recording in recordings {
            let fileName = recording.fileName
            let readableFileName = recording.title.isEmpty ? recording.id : (recording.title + "_" + recording.id)
            logs.info("Uploading file: \(fileName), readable name: \(readableFileName)")

            let source = recording.fileURL
            let destination = iCloudURL.appending(path: readableFileName)

            if !uploadedFiles.contains(fileName) {
              do {
                try fileManager.copyItem(at: source, to: destination)
                logs.info("File copied to iCloud: \(destination)")
              } catch {
                logs.error("Error while copying file to iCloud: \(error)")
              }

              uploadedFiles.append(fileName)
            } else {
              logs.info("File already uploaded: \(fileName)")
            }
          }
        }.value

        logs.info("Finish updating ubiquity container")
      }
    )
  }()

  private static func totalDiskSpaceInBytes() -> UInt64 {
    do {
      let fileURL: URL = .documentsDirectory
      let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
      let capacity = values.volumeAvailableCapacityForImportantUsage
      return UInt64(capacity ?? 0)
    } catch {
      logs.error("Error while getting total disk space: \(error)")
      return 0
    }
  }

  private static func freeDiskSpaceInBytes() -> UInt64 {
    do {
      let fileURL: URL = .documentsDirectory
      let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      let capacity = values.volumeAvailableCapacityForImportantUsage
      return UInt64(capacity ?? 0)
    } catch {
      logs.error("Error while getting free disk space: \(error)")
      return 0
    }
  }

  private static func takenSpace() -> UInt64 {
    do {
      let fileURL: URL = .documentsDirectory
      let capacity = try fileURL.directoryTotalAllocatedSize(includingSubfolders: true)
      return UInt64(capacity ?? 0)
    } catch {
      logs.error("Error while getting taken disk space: \(error)")
      return 0
    }
  }

  private static func deleteStorage(_ storage: Storage) async throws {
    let fileURL: URL = .documentsDirectory
    let contents = try FileManager.default.contentsOfDirectory(at: fileURL, includingPropertiesForKeys: nil, options: [])
    for item in contents where item.pathExtension == "wav" {
      try FileManager.default.removeItem(at: item)
    }

    @Shared(.recordings) var recordings: [RecordingInfo]
    recordings.removeAll()
    recordings = try await storage.sync(recordings: recordings)
  }
}

extension StorageClient {
  static var testValue: StorageClient {
    StorageClient()
  }
}
