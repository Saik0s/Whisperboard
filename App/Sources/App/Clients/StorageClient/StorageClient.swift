import AppDevUtils
import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import XCTestDynamicOverlay
import Combine

// MARK: - StorageClient

struct StorageClient {
  var read: @Sendable () -> IdentifiedArrayOf<RecordingInfo>
  var readStream: @Sendable () -> AsyncStream<IdentifiedArrayOf<RecordingInfo>>
  var write: @Sendable (IdentifiedArrayOf<RecordingInfo>) -> Void
  var addRecordingInfo: @Sendable (RecordingInfo) async throws -> Void
  var createNewWhisperURL: () -> URL
  var audioFileURLWithName: (String) -> URL
  var waveFileURLWithName: (String) -> URL
  var delete: @Sendable (RecordingInfo.ID) throws -> Void
}

extension DependencyValues {
  var storage: StorageClient {
    get { self[StorageClient.self] }
    set { self[StorageClient.self] = newValue }
  }
}
