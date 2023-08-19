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
  var recordingsInfoStream: AsyncStream<[RecordingInfo]>
  var write: @Sendable (IdentifiedArrayOf<RecordingInfo>) -> Void
  var addRecordingInfo: @Sendable (RecordingInfo) throws -> Void
  var createNewWhisperURL: () -> URL
  var audioFileURLWithName: (String) -> URL
  var waveFileURLWithName: (String) -> URL
  var delete: @Sendable (RecordingInfo.ID) throws -> Void
  var update: @Sendable (RecordingInfo.ID, (inout RecordingInfo) -> Void) throws -> Void
  var freeSpace: () -> UInt64
  var totalSpace: () -> UInt64
  var takenSpace: () -> UInt64
  var deleteStorage: () async throws -> Void
  var setEnableICloudSync: (_ enabled: Bool) async throws -> Void
}

extension DependencyValues {
  var storage: StorageClient {
    get { self[StorageClient.self] }
    set { self[StorageClient.self] = newValue }
  }
}
