import Foundation

// MARK: - WhisperParameters

public struct TranscriptionParameters: Hashable, Codable {
  var audioContextSize: Int
  var detectLanguage: Bool
  var durationMilliseconds: Int
  var enableTokenTimestamps: Bool
  var entropyThreshold: Float
  var greedyBestOf: Int
  var initialPrompt: String?
  var language: VoiceLanguage
  var lengthPenalty: Float
  var logProbabilityThreshold: Float
  var maxInitialTimestamp: Float
  var maxSegmentLength: Int
  var maxTextContext: Int
  var maxTokensPerSegment: Int
  var noContext: Bool
  var noSpeechThreshold: Float
  var offsetMilliseconds: Int
  var printProgressInfo: Bool
  var printRealtimeResults: Bool
  var printSpecialTokens: Bool
  var printTimestamps: Bool
  var shouldTranslate: Bool
  var singleSegmentOutput: Bool
  var speedUpAudio: Bool
  var splitOnWord: Bool
  var suppressBlank: Bool
  var suppressNonSpeechTokens: Bool
  var temperature: Float
  var temperatureIncrease: Float
  var threadCount: Int
  var timestampTokenProbabilityThreshold: Float
  var timestampTokenSumProbabilityThreshold: Float

  public init(
    audioContextSize: Int = 0,
    detectLanguage: Bool = false,
    durationMilliseconds: Int = 0,
    enableTokenTimestamps: Bool = false,
    entropyThreshold: Float = 2.4,
    greedyBestOf: Int = 2,
    initialPrompt: String? = nil,
    language: VoiceLanguage = .auto,
    lengthPenalty: Float = -1.0,
    logProbabilityThreshold: Float = -1.0,
    maxInitialTimestamp: Float = 1.0,
    maxSegmentLength: Int = 0,
    maxTextContext: Int = 16384,
    maxTokensPerSegment: Int = 0,
    noContext: Bool = true,
    noSpeechThreshold: Float = 0.6,
    offsetMilliseconds: Int = 0,
    printProgressInfo: Bool = true,
    printRealtimeResults: Bool = false,
    printSpecialTokens: Bool = false,
    printTimestamps: Bool = true,
    shouldTranslate: Bool = false,
    singleSegmentOutput: Bool = false,
    speedUpAudio: Bool = false,
    splitOnWord: Bool = false,
    suppressBlank: Bool = true,
    suppressNonSpeechTokens: Bool = false,
    temperature: Float = 0.0,
    temperatureIncrease: Float = 0.4,
    threadCount: Int = min(4, Int(ProcessInfo.processInfo.activeProcessorCount)),
    timestampTokenProbabilityThreshold: Float = 0.01,
    timestampTokenSumProbabilityThreshold: Float = 0.01
  ) {
    self.audioContextSize = audioContextSize
    self.detectLanguage = detectLanguage
    self.durationMilliseconds = durationMilliseconds
    self.enableTokenTimestamps = enableTokenTimestamps
    self.entropyThreshold = entropyThreshold
    self.greedyBestOf = greedyBestOf
    self.initialPrompt = initialPrompt
    self.language = language
    self.lengthPenalty = lengthPenalty
    self.logProbabilityThreshold = logProbabilityThreshold
    self.maxInitialTimestamp = maxInitialTimestamp
    self.maxSegmentLength = maxSegmentLength
    self.maxTextContext = maxTextContext
    self.maxTokensPerSegment = maxTokensPerSegment
    self.noContext = noContext
    self.noSpeechThreshold = noSpeechThreshold
    self.offsetMilliseconds = offsetMilliseconds
    self.printProgressInfo = printProgressInfo
    self.printRealtimeResults = printRealtimeResults
    self.printSpecialTokens = printSpecialTokens
    self.printTimestamps = printTimestamps
    self.shouldTranslate = shouldTranslate
    self.singleSegmentOutput = singleSegmentOutput
    self.speedUpAudio = speedUpAudio
    self.splitOnWord = splitOnWord
    self.suppressBlank = suppressBlank
    self.suppressNonSpeechTokens = suppressNonSpeechTokens
    self.temperature = temperature
    self.temperatureIncrease = temperatureIncrease
    self.threadCount = threadCount
    self.timestampTokenProbabilityThreshold = timestampTokenProbabilityThreshold
    self.timestampTokenSumProbabilityThreshold = timestampTokenSumProbabilityThreshold
  }
}
