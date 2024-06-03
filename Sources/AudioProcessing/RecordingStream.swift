import AVFoundation
import Common
import Foundation
import WhisperKit

// MARK: - RecordingStream

public actor RecordingStream {
  public struct State: Equatable, Sendable {
    public var isRecording = false
    public var isPaused = false
    public var fileURL: URL?

    public var waveSamples: [Float] = []
    public var duration: TimeInterval = 0
  }

  public var state: State = .init() {
    didSet {
      stateChangeCallback?(state)
    }
  }

  private let audioProcessor: AudioProcessor
  private var audioFile: AVAudioFile?
  private var stateChangeCallback: ((State) -> Void)? = nil

  public init(audioProcessor: AudioProcessor) {
    self.audioProcessor = audioProcessor
  }

  public func startRecording(at fileURL: URL, callback: @escaping (State) -> Void) async throws {
    stateChangeCallback = callback

    guard !state.isRecording else {
      throw NSError(domain: "TranscriptionStream", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording is already in progress."])
    }

    guard await AudioProcessor.requestRecordPermission() else {
      throw NSError(domain: "TranscriptionStream", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone access was not granted."])
    }

    state.fileURL = fileURL

    let converter = try audioProcessor.startFileRecording { [weak self] buffer, _ in
      Task { [weak self] in
        await self?.onAudioBufferCallback(buffer)
      }
    }

    audioFile = try AVAudioFile(forWriting: fileURL, settings: converter.inputFormat.settings)

    state.isRecording = true
    state.isPaused = false
  }

  public func stopRecording() {
    audioProcessor.stopRecording()
    logs.info("Recording has ended")
    audioFile = nil
    state.isRecording = false
    state.isPaused = false
    stateChangeCallback = nil
  }

  public func pauseRecording() {
    audioProcessor.pauseRecording()
    logs.info("Recording has been paused")
    state.isPaused = true
  }

  public func resumeRecording() {
    // TODO: replace with new resumeRecording method
    do {
      try audioProcessor.audioEngine?.start()
      logs.info("Recording has been resumed")
      state.isPaused = false
    } catch {
      logs.error("Failed to resume recording: \(error.localizedDescription)")
      stopRecording()
    }
  }

  private func onAudioBufferCallback(_ buffer: AVAudioPCMBuffer) {
    state.waveSamples = audioProcessor.relativeEnergy

    // Write buffer to audio file
    do {
      try audioFile?.write(from: buffer)
      if let audioFile {
        let frameCount = audioFile.length
        let sampleRate = audioFile.fileFormat.sampleRate
        state.duration = Double(frameCount) / sampleRate
      } else {
        state.duration = 0
      }
    } catch {
      logs.error("Failed to write audio buffer to file: \(error.localizedDescription)")
    }
  }
}
