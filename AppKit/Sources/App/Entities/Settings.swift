import Foundation
import RecognitionKit

struct Settings: Codable, Hashable {
  var voiceLanguage: VoiceLanguage = .auto
  var isParallelEnabled: Bool = false
  var isRemoteTranscriptionEnabled: Bool = false
}
