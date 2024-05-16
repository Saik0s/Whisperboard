import AVFoundation
import Dependencies
import Foundation
import WhisperKit

extension AudioProcessor {
  func setupEngineForRecording(inputDeviceID: DeviceID? = nil, rawBufferCallback: ((AVAudioPCMBuffer) -> Void)? = nil) throws -> AVAudioEngine {
    let audioEngine = AVAudioEngine()
    let inputNode = audioEngine.inputNode

    #if os(macOS)
      if let inputDeviceID {
        assignAudioInput(inputNode: inputNode, inputDeviceID: inputDeviceID)
      }
    #endif

    let hardwareSampleRate = audioEngine.inputNode.inputFormat(forBus: 0).sampleRate
    let inputFormat = inputNode.outputFormat(forBus: 0)

    guard let nodeFormat = AVAudioFormat(
      commonFormat: inputFormat.commonFormat,
      sampleRate: hardwareSampleRate,
      channels: inputFormat.channelCount,
      interleaved: inputFormat.isInterleaved
    ) else {
      throw WhisperKitError.audioProcessingFailed("Failed to create node format")
    }

    // Desired format (16,000 Hz, 1 channel)
    guard let desiredFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: Double(WhisperKit.sampleRate),
      channels: AVAudioChannelCount(1),
      interleaved: false
    ) else {
      throw WhisperKitError.audioProcessingFailed("Failed to create desired format")
    }

    guard let converter = AVAudioConverter(from: nodeFormat, to: desiredFormat) else {
      throw WhisperKitError.audioProcessingFailed("Failed to create audio converter")
    }

    let bufferSize = AVAudioFrameCount(minBufferLength) // 100ms - 400ms supported
    inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nodeFormat) { [weak self] (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
      guard let self else { return }

      var buffer = buffer
      if !buffer.format.sampleRate.isEqual(to: Double(WhisperKit.sampleRate)) {
        do {
          buffer = try Self.resampleBuffer(buffer, with: converter)
        } catch {
          Logging.error("Failed to resample buffer: \(error)")
          return
        }
      }

      if let rawBufferCallback {
        rawBufferCallback(buffer)
      }

      let newBufferArray = Self.convertBufferToArray(buffer: buffer)
      processBuffer(newBufferArray)
    }

    audioEngine.prepare()
    try audioEngine.start()

    return audioEngine
  }

  func startFileRecording(
    inputDeviceID: DeviceID? = nil,
    rawBufferCallback: ((AVAudioPCMBuffer) -> Void)? = nil,
    callback: (([Float]) -> Void)? = nil
  ) throws {
    audioSamples = []
    audioEnergy = []

    @Dependency(\.audioSession) var audioSession: AudioSessionClient
    try audioSession.enable(.record, true)

    audioEngine = try setupEngineForRecording(inputDeviceID: inputDeviceID, rawBufferCallback: rawBufferCallback)

    audioBufferCallback = callback
  }
}
