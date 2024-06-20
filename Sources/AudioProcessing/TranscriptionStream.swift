import Accelerate
import AVFoundation
import Common
import ComposableArchitecture
import CoreML
import Dependencies
import Foundation
import WhisperKit

// MARK: - TranscriptionStream

public actor TranscriptionStream {
  public static let modelDirURL: URL = .documentsDirectory.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")

  public struct State {
    public var currentFallbacks: Int = 0
    public var lastBufferSize: Int = 0
    public var lastConfirmedSegmentEndSeconds: Float = 0
    public var confirmedSegments: [TranscriptionSegment] = []
    public var unconfirmedSegments: [TranscriptionSegment] = []
    public var isWorking = false
    public var transcriptionProgress: TranscriptionProgress?
    public var transcriptionProgressFraction: Double = 0

    public var selectedModel: String = WhisperKit.recommendedModels().default
    public var repoName: String = "argmaxinc/whisperkit-coreml"
    public var selectedLanguage: String = "english"
    public var enableTimestamps = true
    public var enablePromptPrefill = true
    public var enableCachePrefill = true
    public var skipSpecialTokens = true
    public var enableEagerDecoding = false
    public var temperatureStart: Double = 0
    public var fallbackCount: Double = 5
    public var compressionCheckWindow: Int = 60
    public var sampleLength: Double = 224
    public var silenceThreshold: Double = 0.3
    public var useVAD = true
    public var tokenConfirmationsNeeded: Double = 2
    public var chunkingStrategy: ChunkingStrategy = .none
    public var encoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine
    public var decoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine

    public var modelState: ModelState = .unloaded
    public var remoteModels: [String] = []
    public var localModels: [String] = []
    public var localModelPath: String = ""
    public var availableModels: [String] = []
    public var availableLanguages: [String] = []
    public var loadingProgressValue: Float = 0.0
    public var specializationProgressRatio: Float = 0.7
    public var currentText: String = ""
    public var currentChunks: [Int: (chunkText: [String], fallbacks: Int)] = [:]

    public var prevWords: [WordTiming] = []
    public var lastAgreedWords: [WordTiming] = []
    public var confirmedWords: [WordTiming] = []
    public var confirmedText: String = ""
    public var hypothesisWords: [WordTiming] = []
    public var hypothesisText: String = ""

    public var eagerResults: [TranscriptionResult?] = []
    public var lastAgreedSeconds: Float = 0.0

    public var totalInferenceTime: TimeInterval = 0
    public var tokensPerSecond: TimeInterval = 0
    public var effectiveRealTimeFactor: TimeInterval = 0
    public var effectiveSpeedFactor: TimeInterval = 0
    public var currentEncodingLoops: Int = 0
    public var currentLag: TimeInterval = 0

    public let requiredSegmentsForConfirmation: Int = 2

    public let task: DecodingTask = .transcribe

    fileprivate var firstTokenTime: TimeInterval = 0
    fileprivate var pipelineStart: TimeInterval = 0
    fileprivate var prevResult: TranscriptionResult? = nil
  }

  public var state: TranscriptionStream.State = .init() {
    didSet {
      let copyState = state
      DispatchQueue.main.async { [stateChangeCallback] in
        stateChangeCallback?(copyState)
      }
    }
  }

  public var stateChangeCallback: ((State) -> Void)?

  private var whisperKit: WhisperKit?
  private let audioProcessor: AudioProcessor

  public init(audioProcessor: AudioProcessor) {
    self.audioProcessor = audioProcessor
  }

  func fetchModels() async throws {
    logs.debug("Starting fetchModels")
    state.availableModels = [state.selectedModel]
    logs.debug("Initial available models: \(state.availableModels)")

    let modelPath = TranscriptionStream.modelDirURL.path
    logs.debug("Model path: \(modelPath)")

    if FileManager.default.fileExists(atPath: modelPath) {
      state.localModelPath = modelPath
      logs.debug("Local model path exists: \(modelPath)")
      do {
        let downloadedModels = try FileManager.default.contentsOfDirectory(atPath: modelPath)
        logs.debug("Downloaded models: \(downloadedModels)")
        for model in downloadedModels where !state.localModels.contains(model) {
          self.state.localModels.append(model)
          logs.debug("Added local model: \(model)")
        }
      } catch {
        logs.error("Error enumerating files at \(modelPath): \(error.localizedDescription)")
      }
    }

    state.localModels = WhisperKit.formatModelFiles(state.localModels)
    logs.debug("Formatted local models: \(state.localModels)")
    for model in state.localModels {
      if !state.availableModels.contains(model) {
        state.availableModels.append(model)
        logs.debug("Added to available models: \(model)")
      }
    }

    state.remoteModels = try await WhisperKit.fetchAvailableModels(from: state.repoName)
    logs.debug("Fetched remote models: \(state.remoteModels)")
    for model in state.remoteModels {
      if !state.availableModels.contains(model) {
        state.availableModels.append(model)
        logs.debug("Added remote model to available models: \(model)")
      }
    }
    logs.debug("Completed fetchModels")
  }

  func loadModel(_ model: String, redownload: Bool = false) async throws {
    logs.debug("Starting loadModel with model: \(model), redownload: \(redownload)")
    whisperKit = nil
    logs.info("Initializing WhisperKit")
    whisperKit = try await WhisperKit(
      computeOptions: getComputeOptions(),
      audioProcessor: audioProcessor,
      verbose: false,
      logLevel: .info,
      prewarm: false,
      load: false,
      download: false
    )
    logs.info("Finished initializing WhisperKit")
    guard let whisperKit else {
      logs.error("WhisperKit initialization failed")
      return
    }

    let folder: URL? = if state.localModels.contains(model) && !redownload {
      URL(fileURLWithPath: state.localModelPath).appendingPathComponent(model)
    } else {
      try await WhisperKit.download(variant: model, from: state.repoName, progressCallback: { progress in
        self.state.loadingProgressValue = Float(progress.fractionCompleted) * self.state.specializationProgressRatio
        self.state.modelState = .downloading
        logs.debug("Downloading model: \(model), progress: \(self.state.loadingProgressValue)")
      })
    }

    state.loadingProgressValue = state.specializationProgressRatio
    state.modelState = .downloaded
    logs.debug("Model downloaded: \(model)")

    if let modelFolder = folder {
      whisperKit.modelFolder = modelFolder
      logs.debug("Model folder set: \(modelFolder)")

      state.loadingProgressValue = state.specializationProgressRatio
      state.modelState = .prewarming
      logs.debug("Prewarming model: \(model)")

      let progressBarTask = Task {
        await self.updateProgressBar(targetProgress: 0.9, maxTime: 240)
      }

      do {
        try await whisperKit.prewarmModels()
        progressBarTask.cancel()
        logs.debug("Prewarming completed for model: \(model)")
      } catch {
        progressBarTask.cancel()
        logs.error("Error during prewarming: \(error.localizedDescription)")
        if !redownload {
          try await loadModel(model, redownload: true)
          return
        } else {
          state.modelState = .unloaded
          return
        }
      }

      state.loadingProgressValue = state.specializationProgressRatio + 0.9 * (1 - state.specializationProgressRatio)
      state.modelState = .loading
      logs.debug("Loading model: \(model)")

      try await whisperKit.loadModels()
      logs.debug("Model loaded: \(model)")

      if !state.localModels.contains(model) {
        state.localModels.append(model)
        logs.debug("Added model to local models: \(model)")
      }

      state.availableLanguages = Constants.languages.map(\.key).sorted()
      state.loadingProgressValue = 1.0
      state.modelState = whisperKit.modelState
      logs.debug("Model state updated: \(state.modelState)")
    }
  }

  public func deleteModel(_ model: String) async throws {
    logs.debug("Starting deleteModel with model: \(model)")
    if model == state.selectedModel {
      await whisperKit?.unloadModels()
      state.selectedModel = state.availableModels.first ?? WhisperKit.recommendedModels().default
      logs.debug("Unloaded selected model: \(model), new selected model: \(state.selectedModel)")
    }

    let modelPath = state.localModelPath.appendingPathComponent(model)
    state.localModels.removeAll(where: { $0 == model })
    try FileManager.default.removeItem(atPath: modelPath)
    logs.debug("Deleted model: \(model) at path: \(modelPath)")
  }

  private func updateProgressBar(targetProgress: Float, maxTime: TimeInterval) async {
    logs.debug("Starting updateProgressBar with targetProgress: \(targetProgress), maxTime: \(maxTime)")
    let initialProgress = state.loadingProgressValue
    let decayConstant = -log(1 - targetProgress) / Float(maxTime)
    logs.debug("Initial progress: \(initialProgress), decayConstant: \(decayConstant)")

    let startTime = Date()

    while true {
      let elapsedTime = Date().timeIntervalSince(startTime)
      let decayFactor = exp(-decayConstant * Float(elapsedTime))
      let progressIncrement = (1 - initialProgress) * (1 - decayFactor)
      let currentProgress = initialProgress + progressIncrement

      state.loadingProgressValue = currentProgress
      logs.debug("Updated progress bar: \(currentProgress)")

      if currentProgress >= targetProgress {
        logs.debug("Target progress reached: \(targetProgress)")
        break
      }

      do {
        try await Task.sleep(nanoseconds: 100_000_000)
      } catch {
        logs.error("Error during progress bar update: \(error.localizedDescription)")
        break
      }
    }
  }

  public func startRealtimeLoop(callback: @escaping (State) -> Void) async throws {
    logs.debug("Starting real-time loop")
    state.isWorking = true

    while state.isWorking {
      try await transcribeCurrentBuffer(callback: callback)
    }

    logs.debug("Real-time loop ended")
  }

  public func stopRealtimeLoop() {
    state.isWorking = false
    stateChangeCallback = nil
  }

  public func resetState() {
    state = .init()
  }

  public func transcribeCurrentBufferVADChunked(callback: @escaping (State) -> Void) async throws {
    logs.debug("Start VAD chunked transcription")
    stateChangeCallback = callback
    state.isWorking = true
    state.useVAD = false

    logs.debug("Starting VAD chunked transcription")
    let buffer = Array(audioProcessor.audioSamples)
    logs.debug("Audio buffer size: \(buffer.count)")

    logs.debug("Transcribing audio samples with VAD chunking")
    let transcriptionResults = try await transcribeAudioSamples(buffer, useVADChunking: true)
    logs.debug("Merging transcription results")
    let transcription = mergeTranscriptionResults(transcriptionResults)
    logs.debug("Transcription completed")

    state.confirmedSegments = transcription.segments
    state.currentText = transcription.text
    state.confirmedText = transcription.text
    state.transcriptionProgressFraction = 1
    state.isWorking = false

    state.tokensPerSecond = transcription.timings.tokensPerSecond
    state.firstTokenTime = transcription.timings.firstTokenTime
    state.pipelineStart = transcription.timings.pipelineStart
    state.currentLag = transcription.timings.decodingLoop
    state.currentEncodingLoops += Int(transcription.timings.totalEncodingRuns)
    let totalAudio = Double(buffer.count) / Double(WhisperKit.sampleRate)
    state.totalInferenceTime += transcription.timings.fullPipeline
    state.effectiveRealTimeFactor = Double(state.totalInferenceTime) / totalAudio
    state.effectiveSpeedFactor = totalAudio / Double(state.totalInferenceTime)
    state.confirmedWords = transcription.allWords
    logs.debug("Updated state with transcription timings and factors")

    logs.debug("VAD chunked transcription completed")
  }

  public func transcribeCurrentBuffer(callback: @escaping (State) -> Void) async throws {
    logs.debug("Starting transcription of current buffer")
    stateChangeCallback = callback
    state.isWorking = true

    // Retrieve the current audio buffer from the audio processor
    let currentBuffer = audioProcessor.audioSamples

    // Calculate the size and duration of the next buffer segment
    let nextBufferSize = currentBuffer.count - state.lastBufferSize
    let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)

    // Only run the transcribe if the next buffer has at least 1 second of audio
    guard nextBufferSeconds > 1 else {
      return try await Task.sleep(nanoseconds: 100_000_000) // sleep for 100ms for next buffer
    }

    if state.useVAD {
      logs.debug("Voice Activity Detection (VAD) is enabled")

      let voiceDetected = AudioProcessor.isVoiceDetected(
        in: audioProcessor.relativeEnergy,
        nextBufferInSeconds: nextBufferSeconds,
        silenceThreshold: Float(state.silenceThreshold)
      )

      logs.debug("Voice detected: \(voiceDetected)")
      guard voiceDetected else {
        logs.debug("No voice detected, sleeping for 100ms")
        try await Task.sleep(nanoseconds: 100_000_000)
        return
      }
    }

    // Run transcribe
    state.lastBufferSize = currentBuffer.count
    logs.debug("Running transcription on current buffer")

    let transcriptions = try await transcribeAudioSamples(Array(currentBuffer))
    logs.debug("Transcription completed with results: \(transcriptions)")

    var skipAppend = false
    let transcription = transcriptions.first
    if let result = transcription {
      state.hypothesisWords = result.allWords.filter { $0.start >= state.lastAgreedSeconds }
      logs.debug("Hypothesis words updated: \(state.hypothesisWords)")

      if let prevResult = state.prevResult {
        state.prevWords = prevResult.allWords.filter { $0.start >= state.lastAgreedSeconds }
        let commonPrefix = findLongestCommonPrefix(state.prevWords, state.hypothesisWords)
        logs.info("[EagerMode] Prev \"\((state.prevWords.map(\.word)).joined())\"")
        logs.info("[EagerMode] Next \"\((state.hypothesisWords.map(\.word)).joined())\"")
        logs.info("[EagerMode] Found common prefix \"\((commonPrefix.map(\.word)).joined())\"")

        if commonPrefix.count >= Int(state.tokenConfirmationsNeeded) {
          state.lastAgreedWords = commonPrefix.suffix(Int(state.tokenConfirmationsNeeded))
          state.lastAgreedSeconds = state.lastAgreedWords.first!.start
          logs.info("[EagerMode] Found new last agreed word \"\(state.lastAgreedWords.first!.word)\" at \(state.lastAgreedSeconds) seconds")

          state.confirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - Int(state.tokenConfirmationsNeeded)))
          let currentWords = state.confirmedWords.map(\.word).joined()
          logs.info("[EagerMode] Current:  \(state.lastAgreedSeconds) -> \(Double(audioProcessor.audioSamples.count) / 16000.0) \(currentWords)")
        } else {
          logs.info("[EagerMode] Using same last agreed time \(state.lastAgreedSeconds)")
          skipAppend = true
        }
      }
      state.prevResult = result
    }

    if !skipAppend {
      state.eagerResults.append(transcription)
      logs.debug("Appended transcription to eagerResults")
    }

    let finalWords = state.confirmedWords.map(\.word).joined()
    state.confirmedText = finalWords
    logs.debug("Updated confirmed text: \(finalWords)")

    let lastHypothesis = state.lastAgreedWords + findLongestDifferentSuffix(state.prevWords, state.hypothesisWords)
    state.hypothesisText = lastHypothesis.map(\.word).joined()
    logs.debug("Updated hypothesis text: \(state.hypothesisText)")

    let mergedResult = mergeTranscriptionResults(state.eagerResults, confirmedWords: state.confirmedWords)
    let segments = mergedResult.segments
    logs.debug("Merged transcription results into segments: \(segments.count)")

    state.tokensPerSecond = transcription?.timings.tokensPerSecond ?? 0
    state.firstTokenTime = transcription?.timings.firstTokenTime ?? 0
    state.pipelineStart = transcription?.timings.pipelineStart ?? 0
    state.currentLag = transcription?.timings.decodingLoop ?? 0
    state.currentEncodingLoops += Int(transcription?.timings.totalEncodingRuns ?? 0)
    let totalAudio = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
    state.totalInferenceTime += transcription?.timings.fullPipeline ?? 0
    state.effectiveRealTimeFactor = Double(state.totalInferenceTime) / totalAudio
    state.effectiveSpeedFactor = totalAudio / Double(state.totalInferenceTime)
    logs.debug("Updated state with transcription timings and factors")

    if segments.count > state.requiredSegmentsForConfirmation {
      let numberOfSegmentsToConfirm = segments.count - state.requiredSegmentsForConfirmation
      let confirmedSegmentsArray = Array(segments.prefix(numberOfSegmentsToConfirm))
      let remainingSegments = Array(segments.suffix(state.requiredSegmentsForConfirmation))
      logs.debug("Segments to confirm: \(confirmedSegmentsArray.count), remaining segments: \(remainingSegments.count)")

      if let lastConfirmedSegment = confirmedSegmentsArray.last, lastConfirmedSegment.end > state.lastConfirmedSegmentEndSeconds {
        state.lastConfirmedSegmentEndSeconds = lastConfirmedSegment.end
        if !state.confirmedSegments.contains(confirmedSegmentsArray) {
          state.confirmedSegments.append(contentsOf: confirmedSegmentsArray)
          logs.debug("Appended confirmed segments: \(confirmedSegmentsArray.count)")
        }
      }
      state.unconfirmedSegments = remainingSegments
    } else {
      state.unconfirmedSegments = segments
    }
    logs.debug("Updated unconfirmed segments: \(state.unconfirmedSegments.count)")
  }

  private func transcribeAudioSamples(_ samples: [Float], useVADChunking: Bool = false) async throws -> [TranscriptionResult] {
    guard let whisperKit else {
      logs.error("WhisperKit not initialized")
      throw NSError(domain: "WhisperKit not initialized", code: 1)
    }

    logs.debug("Starting transcription with \(samples.count) audio samples")

    var options = DecodingOptions(
      verbose: false,
      task: state.task,
      language: Constants.languages[state.selectedLanguage, default: Constants.defaultLanguageCode],
      temperature: Float(state.temperatureStart),
      temperatureIncrementOnFallback: 0.2,
      temperatureFallbackCount: Int(state.fallbackCount),
      sampleLength: Int(state.sampleLength),
      topK: 5,
      usePrefillPrompt: state.enablePromptPrefill,
      usePrefillCache: state.enableCachePrefill,
      skipSpecialTokens: state.skipSpecialTokens,
      withoutTimestamps: false,
      wordTimestamps: true,
      suppressBlank: true,
      supressTokens: nil,
      compressionRatioThreshold: 2.4,
      logProbThreshold: -1.0,
      firstTokenLogProbThreshold: -1.5,
      noSpeechThreshold: 0.3,
      concurrentWorkerCount: 0,
      chunkingStrategy: useVADChunking ? .vad : ChunkingStrategy.none
    )
    options.clipTimestamps = [state.lastConfirmedSegmentEndSeconds]
    let lastAgreedTokens = state.lastAgreedWords.flatMap(\.tokens)
    options.prefixTokens = lastAgreedTokens

    let checkWindow = state.compressionCheckWindow

    logs.debug("Decoding options set: \(options)")

    return try await whisperKit.transcribe(audioArray: samples, decodeOptions: options) { [weak self, state] progress in
      Task { [weak self] in
        guard let self else { return }
        await onProgressCallback(progress, isChunked: useVADChunking)
      }

      guard state.isWorking else {
        logs.debug("State is set to not working(probably cancelled), stopping transcription early")
        return false
      }

      return TranscriptionStream.shouldStopEarly(progress: progress, options: options, compressionCheckWindow: checkWindow)
    }
  }

  private func onProgressCallback(_ progress: TranscriptionProgress, isChunked: Bool = false) {
    let fallbacks = Int(progress.timings.totalDecodingFallbacks)
    if isChunked {
      logs.debug("Progress windowId: \(progress.windowId) total windows: \(state.currentChunks.keys.count)")
      let fallbacks = Int(progress.timings.totalDecodingFallbacks)
      let chunkId = progress.windowId

      // First check if this is a new window for the same chunk, append if so
      var updatedChunk = (chunkText: [progress.text], fallbacks: fallbacks)
      if var currentChunk = state.currentChunks[chunkId], let previousChunkText = currentChunk.chunkText.last {
        if progress.text.count >= previousChunkText.count {
          // This is the same window of an existing chunk, so we just update the last value
          currentChunk.chunkText[currentChunk.chunkText.endIndex - 1] = progress.text
          updatedChunk = currentChunk
        } else {
          // This is either a new window or a fallback (only in streaming mode)
          if fallbacks == currentChunk.fallbacks {
            // New window (since fallbacks haven't changed)
            updatedChunk.chunkText = currentChunk.chunkText + [progress.text]
          } else {
            // Fallback, overwrite the previous bad text
            updatedChunk.chunkText[currentChunk.chunkText.endIndex - 1] = progress.text
            updatedChunk.fallbacks = fallbacks
            logs.debug("Fallback occurred: \(fallbacks)")
          }
        }
      }

      // Set the new text for the chunk
      state.currentChunks[chunkId] = updatedChunk
      let joinedChunks = state.currentChunks
        .sorted { $0.key < $1.key }
        .flatMap(\.value.chunkText)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .joined(separator: "\n")

      state.currentText = joinedChunks
      state.currentFallbacks = fallbacks
      state.transcriptionProgressFraction = whisperKit?.progress.fractionCompleted ?? 0.0
    } else {
      state.currentFallbacks = fallbacks
      state.transcriptionProgress = progress
      state.currentText = progress.text.trimmingCharacters(in: .whitespacesAndNewlines)
      state.transcriptionProgressFraction = whisperKit?.progress.fractionCompleted ?? 0.0
    }

    logs.debug("Progress callback: fallbacks=\(fallbacks), text=\(progress.text), avgLogprob=\(String(describing: progress.avgLogprob))")
  }

  private static func shouldStopEarly(progress: TranscriptionProgress, options: DecodingOptions, compressionCheckWindow: Int) -> Bool? {
    let currentTokens = progress.tokens
    logs.debug("Checking if should stop early: currentTokensCount=\(currentTokens.count), compressionCheckWindow=\(compressionCheckWindow)")

    if currentTokens.count > compressionCheckWindow {
      let checkTokens: [Int] = currentTokens.suffix(compressionCheckWindow)
      let compressionRatio = compressionRatio(of: checkTokens)
      logs.debug("Compression ratio: \(compressionRatio) (threshold: \(options.compressionRatioThreshold ?? 0.0))")
      if compressionRatio > options.compressionRatioThreshold ?? 0.0 {
        return false
      }
    }

    if let avgLogprob = progress.avgLogprob, let logProbThreshold = options.logProbThreshold {
      logs.debug("Average log probability: \(avgLogprob) (threshold: \(logProbThreshold))")
      if avgLogprob < logProbThreshold {
        return false
      }
    }

    return nil
  }

  private func getComputeOptions() -> ModelComputeOptions {
    ModelComputeOptions(audioEncoderCompute: state.encoderComputeUnits, textDecoderCompute: state.decoderComputeUnits)
  }
}

public extension TranscriptionStream.State {
  var segments: [TranscriptionSegment] {
    confirmedSegments + unconfirmedSegments
  }
}
