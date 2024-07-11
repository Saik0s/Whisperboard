import Combine
import Common
import ComposableArchitecture
import Dependencies
import Foundation
import UIKit

final class Storage {
  static var containerGroupURL: URL? {
    let appGroupName = "group.whisperboard"
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)?.appending(component: "share")
  }

  private var currentlyRecordingURL: URL?

  init() {}

  func sync(recordings: [RecordingInfo]) async throws -> [RecordingInfo] {
    try await Task(priority: .background) { [weak self] in
      guard let self else { return [] }
      return try await read(currentRecordings: recordings).elements
    }.value
  }

  func setAsCurrentlyRecording(_ url: URL?) {
    currentlyRecordingURL = url
  }

  private func read(currentRecordings: [RecordingInfo]) async throws -> IdentifiedArrayOf<RecordingInfo> {
    var storedRecordings = currentRecordings

    // Update the duration of the recordings that don't have it
    storedRecordings = try await updateDurations(storedRecordings)

    // If there are files in shared container, move them to the documents directory
    await storedRecordings.append(contentsOf: moveSharedFiles(to: Configs.recordingsDirectoryURL))

    // Get the files in the documents directory with the .wav extension
    let recordingFiles = try FileManager.default
      .contentsOfDirectory(atPath: Configs.recordingsDirectoryURL.path)
      .filter { $0.hasSuffix(".wav") }
      // Remove the currently recording file from the list until it is finished
      .filter { $0 != currentlyRecordingURL?.lastPathComponent }

    var recordings: IdentifiedArrayOf<RecordingInfo> = []
    for file in recordingFiles {
      // If the recording is already stored in the database, return it
      if let recording = storedRecordings.first(where: { $0.fileName == file }) {
        recordings.append(recording)
        continue
      }

      logs.warning("Recording \(file) not found in database, creating new info for it")
      let newInfo = try await createInfo(fileName: file)
      recordings.append(newInfo)
    }
    
    // Loop through recordings and delete files with < 1s duration
    recordings = recordings.filter { recording in
      if recording.duration < 1 {
        do {
          try FileManager.default.removeItem(at: recording.fileURL)
          logs.info("Deleted recording \(recording.fileName) with duration < 1s")
          return false
        } catch {
          logs.error("Error deleting recording \(recording.fileName): \(error)")
          return true
        }
      }
      return true
    }

    return recordings.sorted { $0.date > $1.date }.identifiedArray
  }

  private func updateDurations(_ storedRecordings: [RecordingInfo]) async throws -> [RecordingInfo] {
    var updatedRecordings: [RecordingInfo] = storedRecordings
    for index in updatedRecordings.filter({ $0.duration < 1 }).indices {
      do {
        updatedRecordings[index].duration = try await getFileDuration(url: updatedRecordings[index].fileURL)
      } catch {
        logs.error("Error getting duration of recording \(updatedRecordings[index].fileName): \(error)")
      }
    }
    return updatedRecordings
  }

  private func moveSharedFiles(to docURL: URL) async -> [RecordingInfo] {
    var recordings: [RecordingInfo] = []
    if let containerGroupURL = Self.containerGroupURL, FileManager.default.fileExists(atPath: containerGroupURL.path) {
      do {
        for file in try FileManager.default.contentsOfDirectory(atPath: containerGroupURL.path) {
          let sourceURL = containerGroupURL.appendingPathComponent(file)
          let newFileName = UUID().uuidString + ".wav"
          let destinationURL = docURL.appending(path: newFileName)
          try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
          let duration = try await getFileDuration(url: destinationURL)
          let recording = RecordingInfo(
            fileName: newFileName,
            title: file,
            date: Date(),
            duration: duration
          )
          recordings.append(recording)
          logs.info("successfully moved file \(file) to \(destinationURL.path)")
          logs.info("recording: \(recording)")
        }
      } catch {
        logs.error("Error moving files from shared container: \(error)")
      }
    } else {
      logs.error("No shared container found")
    }
    return recordings
  }

  private func createInfo(fileName: String) async throws -> RecordingInfo {
    let docURL = Configs.recordingsDirectoryURL
    let fileURL = docURL.appending(component: fileName)
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let date = attributes[.creationDate] as? Date ?? Date()
    let duration = try await getFileDuration(url: fileURL)
    let recording = RecordingInfo(fileName: fileName, date: date, duration: duration)
    return recording
  }
}
