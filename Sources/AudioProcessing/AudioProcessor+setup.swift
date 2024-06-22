import AVFoundation
import Dependencies
import Foundation
import WhisperKit

extension AudioProcessor {
  func startFileRecording(rawBufferCallback: ((AVAudioPCMBuffer, [Float]) -> Void)? = nil) throws -> AVAudioConverter {
    audioSamples = []
    audioEnergy = []

    let audioEngine = AVAudioEngine()
    let inputNode = audioEngine.inputNode

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

      let initialBuffer = buffer
      var buffer = buffer
      if !buffer.format.sampleRate.isEqual(to: Double(WhisperKit.sampleRate)) {
        do {
          buffer = try Self.resampleBuffer(buffer, with: converter)
        } catch {
          Logging.error("Failed to resample buffer: \(error)")
          return
        }
      }

      let newBufferArray = Self.convertBufferToArray(buffer: buffer)
      processBuffer(newBufferArray)

      if let rawBufferCallback {
        rawBufferCallback(initialBuffer, newBufferArray)
      }
    }

    audioEngine.prepare()
    try audioEngine.start()

    self.audioEngine = audioEngine

    return converter
  }
}
