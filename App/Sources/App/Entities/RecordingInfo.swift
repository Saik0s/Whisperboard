import AppDevUtils
import Foundation

public struct RecordingInfo: Identifiable, Hashable, Then, Codable {
  public var fileName: String = UUID().uuidString + ".wav"
  public var title = ""
  public var date: Date
  public var duration: TimeInterval
  public var text: String = ""
  public var isTranscribed = false

  public var id: String { fileName }
}
