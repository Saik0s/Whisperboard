import AppDevUtils
import Foundation

// MARK: - RecordingInfo

public struct RecordingInfo: Identifiable, Hashable, Then, Codable {
  public var fileName: String = UUID().uuidString + ".wav"
  public var title = ""
  public var date: Date
  public var duration: TimeInterval
  public var text: String = ""
  public var isTranscribed = false

  public var id: String { fileName }
}

#if DEBUG
  extension RecordingInfo {
    static let mock = RecordingInfo(
      fileName: "mock.wav",
      title: "Mock",
      date: Date(),
      duration: 10,
      text: "Mock text",
      isTranscribed: true
    )
  }
#endif
