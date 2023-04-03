import Foundation

// MARK: - VoiceLanguage

struct VoiceLanguage: Codable, Hashable, Identifiable {
  let id: Int32
  let code: String
  let name: String

  init(id: Int32, code: String) {
    self.id = id
    self.code = code

    name = Locale.current.localizedString(forLanguageCode: code) ?? code
  }
}

extension VoiceLanguage {
  static let auto = VoiceLanguage(id: 0, code: "auto")

  var isAuto: Bool {
    code == "auto"
  }
}
