import Foundation

// MARK: - WhisperParameters

public struct TranscriptionParameters: Hashable, Codable {
  var audioContextSize: Int = 0
  var detectLanguage: Bool = false
  var durationMilliseconds: Int = 0
  var enableTokenTimestamps: Bool = false
  var entropyThreshold: Float = 2.4
  var greedyBestOf: Int = 2
  var initialPrompt: String? = nil
  var language: VoiceLanguage = .auto
  var lengthPenalty: Float = -1.0
  var logProbabilityThreshold: Float = -1.0
  var maxInitialTimestamp: Float = 1.0
  var maxSegmentLength: Int = 0
  var maxTextContext: Int = 16384
  var maxTokensPerSegment: Int = 0
  var noContext: Bool = true
  var noSpeechThreshold: Float = 0.6
  var offsetMilliseconds: Int = 0
  var printProgressInfo: Bool = true
  var printRealtimeResults: Bool = false
  var printSpecialTokens: Bool = false
  var printTimestamps: Bool = true
  var shouldTranslate: Bool = false
  var singleSegmentOutput: Bool = false
  var speedUpAudio: Bool = false
  var splitOnWord: Bool = false
  var suppressBlank: Bool = true
  var suppressNonSpeechTokens: Bool = false
  var temperature: Float = 0.0
  var temperatureIncrease: Float = 0.4
  var threadCount: Int = min(4, Int(ProcessInfo.processInfo.activeProcessorCount))
  var timestampTokenProbabilityThreshold: Float = 0.01
  var timestampTokenSumProbabilityThreshold: Float = 0.01

  public init() {}
}
