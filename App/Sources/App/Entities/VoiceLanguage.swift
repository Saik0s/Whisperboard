import Foundation

// MARK: - VoiceLanguage

struct VoiceLanguage {
  let id: Int32
  let name: String
}

extension VoiceLanguage {
  static let auto = VoiceLanguage(id: 0, name: "auto")

  var isAuto: Bool {
    name == "auto"
  }
}
