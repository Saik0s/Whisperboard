import Accelerate
import AVFoundation
import ComposableArchitecture
import CoreML
import Dependencies
import Foundation
import WhisperKit

// MARK: - ModelLoadingStage

@CasePathable
public enum ModelLoadingStage: Sendable, Equatable {
  case downloading(progress: Double)
  case prewarming
  case loading
  case completed
}

// MARK: - TranscriptionStream

public actor TranscriptionStream {
  public struct State: Equatable {
    public var currentFallbacks: Int = 0
    public var lastBufferSize: Int = 0
    public var lastConfirmedSegmentEndSeconds: Float = 0
    public var confirmedSegments: [TranscriptionSegment] = []
    public var unconfirmedSegments: [TranscriptionSegment] = []
    public var liveTranscriptionModelState: ModelLoadingStage = .loading
    public var isWorking = true
    public var transcriptionProgress: TranscriptionProgress?

    public var selectedModel: String = WhisperKit.recommendedModels().default
    public var repoName: String = "argmaxinc/whisperkit-coreml"
    public var selectedLanguage: String = "english"
    public var enableTimestamps: Bool = true
    public var enablePromptPrefill: Bool = true
    public var enableCachePrefill: Bool = true
    public var enableSpecialCharacters: Bool = false
    public var enableEagerDecoding: Bool = false
    public var temperatureStart: Double = 0
    public var fallbackCount: Double = 5
    public var compressionCheckWindow: Double = 60
    public var sampleLength: Double = 224
    public var silenceThreshold: Double = 0.3
    public var useVAD: Bool = true
    public var tokenConfirmationsNeeded: Double = 2
    public var chunkingStrategy: ChunkingStrategy = .none
    public var encoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine
    public var decoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine

    public var modelState: ModelState = .unloaded
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
    public var lastConfirmedSegmentEndSeconds: Float = 0

    public let requiredSegmentsForConfirmation: Int = 2

    public let task: DecodingTask = .transcribe
  }

  private var state: TranscriptionStream.State = .init() {
    didSet {
      stateChangeCallback?(state)
    }
  }

  private var whisperKit: WhisperKit?

  private let audioProcessor: AudioProcessor
  private let stateChangeCallback: ((State) -> Void)?

  public init(audioProcessor: AudioProcessor, stateChangeCallback: ((State) -> Void)?) {
    self.audioProcessor = audioProcessor
    self.stateChangeCallback = stateChangeCallback
  }

  func fetchModels() async {
    state.availableModels = [state.selectedModel]

    if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
      let modelPath = documents.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml").path

      if FileManager.default.fileExists(atPath: modelPath) {
        state.localModelPath = modelPath
        do {
          let downloadedModels = try FileManager.default.contentsOfDirectory(atPath: modelPath)
          for model in downloadedModels where !state.localModels.contains(model) {
            self.state.localModels.append(model)
          }
        } catch {
          print("Error enumerating files at \(modelPath): \(error.localizedDescription)")
        }
      }
    }

    state.localModels = WhisperKit.formatModelFiles(state.localModels)
    for model in state.localModels {
      if !state.availableModels.contains(model) {
        state.availableModels.append(model)
      }
    }

    let remoteModels = try await WhisperKit.fetchAvailableModels(from: state.repoName)
    for model in remoteModels {
      if !state.availableModels.contains(model) {
        state.availableModels.append(model)
      }
    }
  }

  func loadModel(_ model: String, redownload: Bool = false) async throws {
    whisperKit = nil
    logs.info("Initializing WhisperKit")
    whisperKit = try await WhisperKit(
      computeOptions: getComputeOptions(),
      audioProcessor: audioProcessor,
      verbose: true,
      logLevel: .debug,
      prewarm: false,
      load: false,
      download: false
    )
    logs.info("Finished initializing WhisperKit")
    guard let whisperKit else { return }

    var folder: URL? = if localModels.contains(model) && !redownload {
      URL(fileURLWithPath: localModelPath).appendingPathComponent(model)
    } else {
      try await WhisperKit.download(variant: model, from: state.repoName, progressCallback: { progress in
        self.state.loadingProgressValue = Float(progress.fractionCompleted) * self.state.specializationProgressRatio
        self.state.modelState = .downloading
      })
    }

    state.loadingProgressValue = state.specializationProgressRatio
    state.modelState = .downloaded

    if let modelFolder = folder {
      whisperKit.modelFolder = modelFolder

      state.loadingProgressValue = state.specializationProgressRatio
      state.modelState = .prewarming

      let progressBarTask = Task {
        await self.updateProgressBar(targetProgress: 0.9, maxTime: 240)
      }

      do {
        try await whisperKit.prewarmModels()
        progressBarTask.cancel()
      } catch {
        progressBarTask.cancel()
        if !redownload {
          loadModel(model, redownload: true)
          return
        } else {
          modelState = .unloaded
          return
        }
      }

      state.loadingProgressValue = state.specializationProgressRatio + 0.9 * (1 - state.specializationProgressRatio)
      state.modelState = .loading

      try await whisperKit.loadModels()

      if !state.localModels.contains(model) {
        state.localModels.append(model)
      }

      state.availableLanguages = Constants.languages.map(\.key).sorted()
      state.loadingProgressValue = 1.0
      state.modelState = whisperKit.modelState
    }
  }

  private func updateProgressBar(targetProgress: Float, maxTime: TimeInterval) async {
    let initialProgress = loadingProgressValue
    let decayConstant = -log(1 - targetProgress) / Float(maxTime)

    let startTime = Date()

    while true {
      let elapsedTime = Date().timeIntervalSince(startTime)

      let decayFactor = exp(-decayConstant * Float(elapsedTime))
      let progressIncrement = (1 - initialProgress) * (1 - decayFactor)
      let currentProgress = initialProgress + progressIncrement

      await MainActor.run {
        loadingProgressValue = currentProgress
      }

      if currentProgress >= targetProgress {
        break
      }

      do {
        try await Task.sleep(nanoseconds: 100_000_000)
      } catch {
        break
      }
    }
  }

  public func startRealtimeLoop(shouldStopWhenNoSamplesLeft: Bool = false) async throws {
    while state.isWorking && (shouldStopWhenNoSamplesLeft ? !audioProcessor.audioSamples.isEmpty : true) {
      do {
        try await transcribeCurrentBuffer()
      } catch {
        logs.error("Error: \(error.localizedDescription)")
        throw error
      }
    }
  }

  public func stopRealtimeLoop() {
    state.isWorking = false
  }

  public func resetState() {
    state = .init()
  }

  private func transcribeCurrentBuffer() async throws {
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
      let voiceDetected = AudioProcessor.isVoiceDetected(
        in: audioProcessor.relativeEnergy,
        nextBufferInSeconds: nextBufferSeconds,
        silenceThreshold: Float(state.silenceThreshold)
      )
      guard voiceDetected else {
        await MainActor.run {
          if self.state.currentText.isEmpty {
            self.state.currentText = "Waiting for speech..."
          }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        return
      }
    }

    // Run transcribe
    state.lastBufferSize = currentBuffer.count

    let transcriptions = try await transcribeAudioSamples(Array(currentBuffer))

    var skipAppend = false
    if let result = transcriptions.first {
      hypothesisWords = result.allWords.filter { $0.start >= self.lastAgreedSeconds }

      if let prevResult {
        state.prevWords = state.prevResult.allWords.filter { $0.start >= state.lastAgreedSeconds }
        let commonPrefix = findLongestCommonPrefix(state.prevWords, state.hypothesisWords)
        logs.info("[EagerMode] Prev \"\((state.prevWords.map(\.word)).joined())\"")
        logs.info("[EagerMode] Next \"\((hypothesisWords.map(\.word)).joined())\"")
        logs.info("[EagerMode] Found common prefix \"\((commonPrefix.map(\.word)).joined())\"")

        if commonPrefix.count >= Int(state.tokenConfirmationsNeeded) {
          state.lastAgreedWords = commonPrefix.suffix(Int(state.tokenConfirmationsNeeded))
          state.lastAgreedSeconds = state.lastAgreedWords.first!.start
          logs
            .info(
              "[EagerMode] Found new last agreed word \"\(lastAgreedWords.first!.word)\" at \(lastAgreedSeconds) seconds"
            )

          state.confirmedWords
            .append(contentsOf: commonPrefix.prefix(commonPrefix.count - Int(state.tokenConfirmationsNeeded)))
          let currentWords = state.confirmedWords.map(\.word).joined()
          logs.info("[EagerMode] Current:  \(state.lastAgreedSeconds) -> \(Double(samples.count) / 16000.0) \(currentWords)")
        } else {
          logs.info("[EagerMode] Using same last agreed time \(lastAgreedSeconds)")
          skipAppend = true
        }
      }
      state.prevResult = result
    }

    if !skipAppend {
      state.eagerResults.append(transcription)
    }

    let finalWords = state.confirmedWords.map(\.word).joined()
    state.confirmedText = finalWords

    let lastHypothesis = state.lastAgreedWords + findLongestDifferentSuffix(state.prevWords, state.hypothesisWords)
    state.hypothesisText = lastHypothesis.map(\.word).joined()

    let mergedResult = mergeTranscriptionResults(state.eagerResults, confirmedWords: state.confirmedWords)

    state.currentText = ""
    let segments = mergedResult.segments

    state.tokensPerSecond = transcription?.timings.tokensPerSecond ?? 0
    state.firstTokenTime = transcription?.timings.firstTokenTime ?? 0
    state.pipelineStart = transcription?.timings.pipelineStart ?? 0
    state.currentLag = transcription?.timings.decodingLoop ?? 0
    state.currentEncodingLoops += Int(transcription?.timings.totalEncodingRuns ?? 0)
    let totalAudio = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
    state.totalInferenceTime += transcription?.timings.fullPipeline ?? 0
    state.effectiveRealTimeFactor = Double(state.totalInferenceTime) / totalAudio
    state.effectiveSpeedFactor = totalAudio / Double(state.totalInferenceTime)

    if segments.count > state.requiredSegmentsForConfirmation {
      let numberOfSegmentsToConfirm = segments.count - requiredSegmentsForConfirmation
      let confirmedSegmentsArray = Array(segments.prefix(numberOfSegmentsToConfirm))
      let remainingSegments = Array(segments.suffix(requiredSegmentsForConfirmation))

      if let lastConfirmedSegment = confirmedSegmentsArray.last, lastConfirmedSegment.end > self.lastConfirmedSegmentEndSeconds {
        lastConfirmedSegmentEndSeconds = lastConfirmedSegment.end
        if !confirmedSegments.contains(confirmedSegmentsArray) {
          confirmedSegments.append(contentsOf: confirmedSegmentsArray)
        }
      }
      unconfirmedSegments = remainingSegments
    } else {
      unconfirmedSegments = segments
    }

    // MARK: - regular transcription mode

    // let segments = mergedResult.segments

    // // Logic for moving segments to confirmedSegments
    // if segments.count > state.requiredSegmentsForConfirmation {
    //   // Calculate the number of segments to confirm
    //   let numberOfSegmentsToConfirm = segments.count - state.requiredSegmentsForConfirmation

    //   // Confirm the required number of segments
    //   let confirmedSegmentsArray = Array(segments.prefix(numberOfSegmentsToConfirm))
    //   let remainingSegments = Array(segments.suffix(state.requiredSegmentsForConfirmation))

    //   // Update lastConfirmedSegmentEnd based on the last confirmed segment
    //   if let lastConfirmedSegment = confirmedSegmentsArray.last, lastConfirmedSegment.end > self.state.lastConfirmedSegmentEndSeconds {
    //     state.lastConfirmedSegmentEndSeconds = lastConfirmedSegment.end

    //     // Add confirmed segments to the confirmedSegments array
    //     if !state.confirmedSegments.contains(confirmedSegmentsArray) {
    //       state.confirmedSegments.append(contentsOf: confirmedSegmentsArray)
    //     }
    //   }

    //   // Update transcriptions to reflect the remaining segments
    //   state.unconfirmedSegments = remainingSegments
    // } else {
    //   // Handle the case where segments are fewer or equal to required
    //   state.unconfirmedSegments = segments
    // }
  }

  private func transcribeAudioSamples(_ samples: [Float]) async throws -> [TranscriptionResult] {
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
      skipSpecialTokens: !state.enableSpecialCharacters,
      withoutTimestamps: false,
      wordTimestamps: true,
      suppressBlank: true,
      supressTokens: nil,
      compressionRatioThreshold: 2.4,
      logProbThreshold: -1.0,
      firstTokenLogProbThreshold: -1.5,
      noSpeechThreshold: 0.3,
      concurrentWorkerCount: 1
    )
    options.clipTimestamps = [state.lastConfirmedSegmentEndSeconds]
    let lastAgreedTokens = lastAgreedWords.flatMap(\.tokens)
    options.prefixTokens = lastAgreedTokens
    let checkWindow = state.compressionCheckWindow

    return try await whisperKit.transcribe(audioArray: samples, decodeOptions: options) { [weak self] progress in
      Task { [weak self] in
        await self?.onProgressCallback(progress)
      }
      return TranscriptionStream.shouldStopEarly(progress: progress, options: options, compressionCheckWindow: checkWindow)
    }
  }

  private func onProgressCallback(_ progress: TranscriptionProgress) {
    let fallbacks = Int(progress.timings.totalDecodingFallbacks)
    state.currentFallbacks = fallbacks
    state.transcriptionProgress = progress
    state.currentText = progress.text
  }

  private static func shouldStopEarly(progress: TranscriptionProgress, options: DecodingOptions, compressionCheckWindow: Int) -> Bool? {
    let currentTokens = progress.tokens
    if currentTokens.count > compressionCheckWindow {
      let checkTokens: [Int] = currentTokens.suffix(compressionCheckWindow)
      let compressionRatio = compressionRatio(of: checkTokens)
      if compressionRatio > options.compressionRatioThreshold ?? 0.0 {
        return false
      }
    }

    if let avgLogprob = progress.avgLogprob, let logProbThreshold = options.logProbThreshold {
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
