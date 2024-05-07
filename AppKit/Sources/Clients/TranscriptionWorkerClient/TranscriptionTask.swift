import ComposableArchitecture
import Foundation

// MARK: - TranscriptionTask

struct TranscriptionTask: Identifiable, Codable, Hashable, Then {
  var id = UUID()
  var recordingInfoID: RecordingInfo.ID
  var settings: Settings
  var remoteID: String? = nil
}
