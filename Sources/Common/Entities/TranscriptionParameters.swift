import Foundation

// MARK: - WhisperParameters

public struct TranscriptionParameters: Hashable, Codable {
  public var initialPrompt: String?
  public var language: String?
  public var offsetMilliseconds: Int
  public var shouldTranslate: Bool

  public init(
    initialPrompt: String? = nil,
    language: String? = nil,
    offsetMilliseconds: Int = 0,
    shouldTranslate: Bool = false
  ) {
    self.initialPrompt = initialPrompt
    self.language = language
    self.offsetMilliseconds = offsetMilliseconds
    self.shouldTranslate = shouldTranslate
  }
}
