import Foundation

public struct VoiceLanguage: Codable, Hashable, Identifiable {
  public let id: Int32
  public let code: String
  public let name: String

  public init(id: Int32, code: String) {
    self.id = id
    self.code = code

    name = Locale.current.localizedString(forLanguageCode: code) ?? code
  }
}

public extension VoiceLanguage {
  static let auto = VoiceLanguage(id: -1, code: "auto")

  var isAuto: Bool {
    code == "auto"
  }
}
