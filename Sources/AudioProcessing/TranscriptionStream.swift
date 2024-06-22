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

    public var currentText: String = ""
    public var confirmedSegments: [TranscriptionSegment] = []
    public var unconfirmedSegments: [TranscriptionSegment] = []
    public var unconfirmedText: [String] = []

    public var tokensPerSecond: Double = 0

    public var isWorking = false
    public var transcriptionProgressFraction: Double = 0
    public let requiredSegmentsForConfirmation: Int = 2

    public var selectedModel: String = WhisperKit.recommendedModels().default
    public var repoName: String = "argmaxinc/whisperkit-coreml"
    public var selectedLanguage: String = "english"
    public var enablePromptPrefill = true
    public var enableCachePrefill = true
    public var skipSpecialTokens = true
    public var temperatureStart: Double = 0
    public var fallbackCount: Double = 5
    public var compressionCheckWindow: Int = 60
    public var sampleLength: Double = 224
    public var silenceThreshold: Double = 0.3
    public var useVAD = true
    public var encoderComputeUnits: MLComputeUnits = .cpuAndGPU
    public var decoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine

    public var modelState: ModelState = .unloaded
    public var remoteModels: [String] = []
    public var localModels: [String] = []
    public var localModelPath: String = ""
    public var availableModels: [String] = []
    public var availableLanguages: [String] = []
    public var loadingProgressValue: Float = 0.0
    public var specializationProgressRatio: Float = 0.7

    public let task: DecodingTask = .transcribe
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
  private var options: DecodingOptions = .init()

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
    options = DecodingOptions(
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
      concurrentWorkerCount: 0
    )
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

    let transcription = try await transcribeAudioSamples(Array(currentBuffer))
    logs.debug("Transcription completed with text: \(transcription.text)")

    state.currentText = ""
    state.unconfirmedText = []
    let segments = transcription.segments

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

  public func transcribeAudioFile(_ fileURL: URL, callback: @escaping (TranscriptionProgress, Double) -> Bool?) async throws -> TranscriptionResult {
    guard let whisperKit else {
      logs.error("WhisperKit not initialized")
      throw NSError(domain: "WhisperKit not initialized", code: 1)
    }
    
    options = DecodingOptions(
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
      concurrentWorkerCount: 0
    )

    let results: [TranscriptionResult] = try await whisperKit.transcribe(audioPath: fileURL.path(), decodeOptions: options) { progress in
      return callback(progress, whisperKit.progress.fractionCompleted)
    }

    return mergeTranscriptionResults(results)
  }

  private func transcribeAudioSamples(_ samples: [Float]) async throws -> TranscriptionResult {
    guard let whisperKit else {
      logs.error("WhisperKit not initialized")
      throw NSError(domain: "WhisperKit not initialized", code: 1)
    }

    logs.debug("Starting transcription with \(samples.count) audio samples")
    options.clipTimestamps = [state.lastConfirmedSegmentEndSeconds]
    let checkWindow = state.compressionCheckWindow

    let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options) { [weak self, state, options] progress in
      Task { [weak self] in
        await self?.onProgressCallback(progress)
      }

      guard state.isWorking else {
        logs.debug("State is set to not working(probably cancelled), stopping transcription early")
        return false
      }

      return TranscriptionStream.shouldStopEarly(progress: progress, options: options, compressionCheckWindow: checkWindow)
    }

    return mergeTranscriptionResults(results)
  }

  private func onProgressCallback(_ progress: TranscriptionProgress) {
    let fallbacks = Int(progress.timings.totalDecodingFallbacks)
    if progress.text.count < state.currentText.count {
      if fallbacks == state.currentFallbacks {
        state.unconfirmedText.append(state.currentText)
      } else {
        logs.info("Fallback occured: \(fallbacks)")
      }
    }

    state.currentFallbacks = fallbacks
    state.currentText = progress.text.trimmingCharacters(in: .whitespacesAndNewlines)
    state.transcriptionProgressFraction = whisperKit?.progress.fractionCompleted ?? 0.0
    state.tokensPerSecond = progress.timings.tokensPerSecond

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
