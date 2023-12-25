
import Foundation

// MARK: - TranscriptionTask

struct TranscriptionTask: Identifiable, Codable, Hashable, Then {
  var id = UUID()
  var fileName: String
  var duration: Int64
  var parameters: TranscriptionParameters
  var modelType: VoiceModelType
  var remoteID: String? = nil
  var isRemote: Bool = false
  var segments: [Segment] = [] {
    didSet { parameters.offsetMilliseconds = Int(offset) }
  }

  var offset: Int64 { segments.last?.endTime ?? 0 }
  var progress: Double { Double(offset) / Double(duration) }
}
