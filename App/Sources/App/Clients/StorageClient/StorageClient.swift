import AppDevUtils
import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import XCTestDynamicOverlay

// MARK: - StorageClient

struct StorageClient {
  var read: @Sendable () async throws -> IdentifiedArrayOf<RecordingInfo>
  var write: @Sendable (IdentifiedArrayOf<RecordingInfo>) async throws -> Void
  var createNewWhisperURL: () -> URL
  var audioFileURLWithName: (String) -> URL
  var waveFileURLWithName: (String) -> URL
}

// MARK: TestDependencyKey

extension StorageClient: TestDependencyKey {
  static let previewValue = Self(
    read: {
      [
        RecordingInfo(
          fileName: "test1",
          title: "",
          date: Date(),
          duration: .random(in: 1 ... 10),
          text: "Lorem ipsum",
          isTranscribed: true
        ),
        RecordingInfo(
          fileName: "test2",
          title: "",
          date: Date(),
          duration: .random(in: 1 ... 10),
          text: Array(repeating: "Lorem ipsum ", count: 30).joined(),
          isTranscribed: true
        ),
      ]
    },
    write: { _ in },
    createNewWhisperURL: { URL(filePath: "~/Downloads/1.wav") },
    audioFileURLWithName: { _ in URL(filePath: "~/Downloads/1.wav") },
    waveFileURLWithName: { _ in URL(filePath: "~/Downloads/1.wav") }
  )

  static let testValue = Self(
    read: unimplemented("\(Self.self).read"),
    write: unimplemented("\(Self.self).write"),
    createNewWhisperURL: unimplemented("\(Self.self).createNewWhisperURL"),
    audioFileURLWithName: unimplemented("\(Self.self).audioFileURLWithName"),
    waveFileURLWithName: unimplemented("\(Self.self).waveFileURLWithName")
  )
}

extension DependencyValues {
  var storage: StorageClient {
    get { self[StorageClient.self] }
    set { self[StorageClient.self] = newValue }
  }
}
