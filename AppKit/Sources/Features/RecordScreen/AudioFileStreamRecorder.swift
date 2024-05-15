import Accelerate
import AudioKit
import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import WhisperKit

// MARK: - TranscriptionSegment + Sendable

extension TranscriptionSegment: @unchecked Sendable {}

// MARK: - WordTiming + Sendable

extension WordTiming: @unchecked Sendable {}

// MARK: - AudioFileStreamRecorder

public actor AudioFileStreamRecorder {
  public struct State: Equatable, Sendable, CustomDumpStringConvertible {
    public var currentFallbacks: Int = 0
    public var lastBufferSize: Int = 0
    public var lastConfirmedSegmentEndSeconds: Float = 0
    public var confirmedSegments: [TranscriptionSegment] = []
    public var unconfirmedSegments: [TranscriptionSegment] = []
    public var isTranscriptionEnabled = true
    public var waveSamples: [Float] = []
    public var fileURL: URL?
    public var error: EquatableError?

    public var customDumpDescription: String {
      """
      currentFallbacks: \(currentFallbacks)
      lastBufferSize: \(lastBufferSize)
      lastConfirmedSegmentEndSeconds: \(lastConfirmedSegmentEndSeconds)
      confirmedSegments: [
        \(confirmedSegments.map { "id: \($0.id), seek: \($0.seek), start: \($0.start), end: \($0.end), text: \($0.text)" }.joined(separator: ", "))
      ]
      unconfirmedSegments: [
        \(unconfirmedSegments.map { "id: \($0.id), seek: \($0.seek), start: \($0.start), end: \($0.end), text: \($0.text)" }.joined(separator: ", "))
      ]
      isTranscriptionEnabled: \(isTranscriptionEnabled)
      waveSamples(count): \(waveSamples.count)
      """
    }
  }

  private var nodeRecorder: NodeRecorder?
  private var audioEngine: AudioEngine = AudioEngine()

  private var state: AudioFileStreamRecorder.State = .init() {
    didSet {
      if state != oldValue {
        stateChangeCallback?(state)
      }
    }
  }

  private let requiredSegmentsForConfirmation: Int
  private let compressionCheckWindow: Int
  private let useVAD: Bool
  private let silenceThreshold: Float
  private let stateChangeCallback: ((State) -> Void)?
  private let audioProcessor: AudioProcessor
  private let decodingOptions: DecodingOptions
  private var audioFile: AVAudioFile?
  private let whisperKit: WhisperKit

  private var isRecording: Bool { nodeRecorder?.isRecording ?? false }
  private var isPaused: Bool { nodeRecorder?.isPaused ?? false }

  @Dependency(\.audioSession) var audioSession: AudioSessionClient

  public init(
    whisperKit: WhisperKit,
    audioProcessor: AudioProcessor,
    decodingOptions: DecodingOptions,
    requiredSegmentsForConfirmation: Int = 2,
    compressionCheckWindow: Int = 20,
    useVAD: Bool = true,
    silenceThreshold: Float = 0.3,
    isTranscriptionEnabled: Bool = true,
    stateChangeCallback: ((State) -> Void)?
  ) {
    self.whisperKit = whisperKit
    self.audioProcessor = audioProcessor
    self.decodingOptions = decodingOptions
    self.requiredSegmentsForConfirmation = requiredSegmentsForConfirmation
    self.compressionCheckWindow = compressionCheckWindow
    self.useVAD = useVAD
    self.silenceThreshold = silenceThreshold
    self.stateChangeCallback = stateChangeCallback
    state.isTranscriptionEnabled = isTranscriptionEnabled
  }

  public func startRecording(at fileURL: URL) async throws {
    guard !isRecording else {
      throw NSError(domain: "AudioFileStreamRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording is already in progress."])
    }

    guard await AudioProcessor.requestRecordPermission() else {
      throw NSError(domain: "AudioFileStreamRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone access was not granted."])
    }

    state.fileURL = fileURL

    try nodeRecorder?.reset()
    nodeRecorder = try audioProcessor.createNodeRecorder(audioEngine: audioEngine, fileURL: fileURL, shouldProcessBuffer: state.isTranscriptionEnabled) { [weak self] data in
      Task { [weak self] in
        await self?.onNewChannelData(data)
      }
    }
    try audioEngine.start()
    try nodeRecorder?.record()

    logs.info("Started recording to \(nodeRecorder?.audioFile?.url.path() ?? "-")")

    await realtimeLoop()
  }

  public func stopRecording() {
    nodeRecorder?.stop()
    logs.info("Recording has ended")
    audioEngine.stop()
  }

  public func pauseRecording() {
    nodeRecorder?.pause()
    logs.info("Recording has been paused")
  }

  public func resumeRecording() {
    nodeRecorder?.resume()
    logs.info("Recording has been resumed")
  }

  private func onNewChannelData(_ data: [Float]) {
    state.waveSamples = AudioFileStreamRecorder.getWaveformAdjustedSamples(from: data, samplesPerPixel: WhisperKit.sampleRate / 10)
  }

  private func realtimeLoop() async {
    while isRecording {
      do {
        // wait for the model to load
        if whisperKit.modelState != .loaded || isPaused || !state.isTranscriptionEnabled {
          try await Task.sleep(for: .seconds(0.3))
          continue
        }

        try await transcribeCurrentBuffer()
      } catch {
        logs.error("Error: \(error.localizedDescription)")
      }
    }
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

    if useVAD {
      // Retrieve the current relative energy values from the audio processor
      let currentRelativeEnergy = audioProcessor.relativeEnergy

      // Calculate the number of energy values to consider based on the duration of the next buffer
      // Each energy value corresponds to 1 buffer length (100ms of audio), hence we divide by 0.1
      let energyValuesToConsider = Int(nextBufferSeconds / 0.1)

      // Extract the relevant portion of energy values from the currentRelativeEnergy array
      let nextBufferEnergies = currentRelativeEnergy.suffix(energyValuesToConsider)

      // Determine the number of energy values to check for voice presence
      // Considering up to the last 1 second of audio, which translates to 10 energy values
      let numberOfValuesToCheck = max(10, nextBufferEnergies.count - 10)

      // Check if any of the energy values in the considered range exceed the silence threshold
      // This indicates the presence of voice in the buffer
      let voiceDetected = nextBufferEnergies.prefix(numberOfValuesToCheck).contains { $0 > Float(silenceThreshold) }

      // Only run the transcribe if the next buffer has voice
      if !voiceDetected {
        // Sleep for 100ms and check the next buffer
        return try await Task.sleep(nanoseconds: 100_000_000)
      }
    }

    // Run transcribe
    state.lastBufferSize = currentBuffer.count

    let transcriptions = try await transcribeAudioSamples(Array(currentBuffer))

    let segments = transcriptions.flatMap(\.segments)

    // Logic for moving segments to confirmedSegments
    if segments.count > requiredSegmentsForConfirmation {
      // Calculate the number of segments to confirm
      let numberOfSegmentsToConfirm = segments.count - requiredSegmentsForConfirmation

      // Confirm the required number of segments
      let confirmedSegmentsArray = Array(segments.prefix(numberOfSegmentsToConfirm))
      let remainingSegments = Array(segments.suffix(requiredSegmentsForConfirmation))

      // Update lastConfirmedSegmentEnd based on the last confirmed segment
      if let lastConfirmedSegment = confirmedSegmentsArray.last, lastConfirmedSegment.end > state.lastConfirmedSegmentEndSeconds {
        state.lastConfirmedSegmentEndSeconds = lastConfirmedSegment.end

        // Add confirmed segments to the confirmedSegments array
        if !state.confirmedSegments.contains(confirmedSegmentsArray) {
          state.confirmedSegments.append(contentsOf: confirmedSegmentsArray)
        }
      }

      // Update transcriptions to reflect the remaining segments
      state.unconfirmedSegments = remainingSegments
    } else {
      // Handle the case where segments are fewer or equal to required
      state.unconfirmedSegments = segments
    }
  }

  private func transcribeAudioSamples(_ samples: [Float]) async throws -> [TranscriptionResult] {
    var options = decodingOptions
    options.clipTimestamps = [state.lastConfirmedSegmentEndSeconds]
    let checkWindow = compressionCheckWindow
    return try await whisperKit.transcribe(audioArray: samples, decodeOptions: options) { [weak self] progress in
      Task { [weak self] in
        await self?.onProgressCallback(progress)
      }
      return AudioFileStreamRecorder.shouldStopEarly(progress: progress, options: options, compressionCheckWindow: checkWindow)
    }
  }

  private func onProgressCallback(_ progress: TranscriptionProgress) {
    let fallbacks = Int(progress.timings.totalDecodingFallbacks)
    state.currentFallbacks = fallbacks
  }

  private static func shouldStopEarly(
    progress: TranscriptionProgress,
    options: DecodingOptions,
    compressionCheckWindow: Int
  ) -> Bool? {
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

  private static func getWaveformAdjustedSamples(from samples: [Float], samplesPerPixel: Int) -> [Float] {
    let sampleCount = samples.count
    let adjustedSampleCount = max(64, samplesPerPixel)

    var adjustedSamples = [Float](repeating: 0.0, count: adjustedSampleCount)

    let framesPerBuffer = sampleCount / adjustedSampleCount

    for i in 0 ..< adjustedSampleCount {
      let startIndex = i * framesPerBuffer
      let endIndex = min(startIndex + framesPerBuffer, sampleCount)

      let bufferSamples = Array(samples[startIndex ..< endIndex])

      var rms: Float = 0.0
      vDSP_rmsqv(bufferSamples, 1, &rms, vDSP_Length(bufferSamples.count))

      adjustedSamples[i] = rms
    }

    return adjustedSamples
  }
}
