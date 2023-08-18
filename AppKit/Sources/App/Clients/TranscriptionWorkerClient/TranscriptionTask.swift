import AppDevUtils
import Foundation

// MARK: - TranscriptionTask

public struct TranscriptionTask: Identifiable, Codable, Equatable, Then {
  public var id = UUID()
  let fileURL: URL
  var parameters: TranscriptionParameters
  var modelType: VoiceModelType

  var fileName: String { fileURL.lastPathComponent }
}
