import AVFoundation
import Common
import Foundation
import WhisperKit
import Dependencies

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

  public func resetState() {
    state = .init()
  }

  public func startRecording(at fileURL: URL, callback: @escaping (State) -> Void) async throws {
    stateChangeCallback = callback

    guard !state.isRecording else {
      logs.error("Attempted to start recording, but a recording is already in progress.")
      throw NSError(domain: "TranscriptionStream", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording is already in progress."])
    }

    guard await AudioProcessor.requestRecordPermission() else {
      logs.error("Microphone access was not granted.")
      throw NSError(domain: "TranscriptionStream", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone access was not granted."])
    }

    state.fileURL = fileURL
    logs.info("Starting recording at file URL: \(fileURL)")

    @Dependency(\.audioSession) var audioSession: AudioSessionClient
    try audioSession.enable(.record, true)
    defer { try? audioSession.enable(.record, false) }

    let converter = try audioProcessor.startFileRecording { [weak self] buffer, _ in
      Task { [weak self] in
        await self?.onAudioBufferCallback(buffer)
      }
    }

    audioFile = try AVAudioFile(forWriting: fileURL, settings: converter.inputFormat.settings)
    logs.info("Audio file created for writing at URL: \(fileURL)")

    state.isRecording = true
    state.isPaused = false
    logs.info("Recording started successfully.")

    while state.isRecording {
      try? await Task.sleep(seconds: 0.3)
    }
  }

  public func stopRecording() {
    audioProcessor.stopRecording()
    logs.info("Recording has ended")
    audioFile = nil
    state.isRecording = false
    state.isPaused = false
    stateChangeCallback = nil
    logs.info("Recording state reset and callback cleared.")
  }

  public func pauseRecording() {
    audioProcessor.pauseRecording()
    logs.info("Recording has been paused")
    state.isPaused = true
  }

  public func resumeRecording() {
    do {
      try audioProcessor.resumeRecordingLive()
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
      logs.debug("Audio buffer written to file.")
      if let audioFile {
        let frameCount = audioFile.length
        let sampleRate = audioFile.fileFormat.sampleRate
        state.duration = Double(frameCount) / sampleRate
      } else {
        state.duration = 0
        logs.debug("Audio file is nil, duration reset to 0.")
      }
    } catch {
      logs.error("Failed to write audio buffer to file: \(error.localizedDescription)")
    }
  }
}
