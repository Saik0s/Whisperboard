import AppDevUtils
import AVFoundation
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import XCTestDynamicOverlay

// MARK: - StorageClient

struct StorageClient {
  var read: @Sendable () -> IdentifiedArrayOf<RecordingInfo>
  var recordingsInfoStream: AnyPublisher<[RecordingInfo], Never>
  var write: @Sendable (IdentifiedArrayOf<RecordingInfo>) -> Void
  var addRecordingInfo: @Sendable (RecordingInfo) async throws -> Void
  var createNewWhisperURL: () -> URL
  var audioFileURLWithName: (String) -> URL
  var waveFileURLWithName: (String) -> URL
  var delete: @Sendable (RecordingInfo.ID) throws -> Void
  var update: @Sendable (RecordingInfo.ID, (inout RecordingInfo) -> Void) throws -> Void
}

extension DependencyValues {
  var storage: StorageClient {
    get { self[StorageClient.self] }
    set { self[StorageClient.self] = newValue }
  }
}
