import Foundation

struct Settings: Codable, Hashable {
  var voiceLanguage: VoiceLanguage = .auto
}