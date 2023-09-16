
import Foundation

// MARK: - TranscriptionTask

struct TranscriptionTask: Identifiable, Codable, Equatable, Then {
  var id = UUID()
  let fileURL: URL
  var parameters: TranscriptionParameters
  var modelType: VoiceModelType

  var fileName: String { fileURL.lastPathComponent }
}
