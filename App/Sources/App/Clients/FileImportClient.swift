import AppDevUtils
import AVFoundation
import Dependencies
import Foundation

// MARK: - FileImportClient

struct FileImportClient {
  var importFile: @Sendable (_ from: URL, _ to: URL) async throws -> Void
}

// MARK: DependencyKey

extension FileImportClient: DependencyKey {
  static var liveValue: Self {
    Self(
      importFile: { from, to in
        // let tmpPath = to.deletingLastPathComponent().appending(component: "tmp.\(to.lastPathComponent)")
        // try FileManager.default.copyItem(at: from, to: tmpPath)
        // try await _importFile(from: from, to: to)
        // try? FileManager.default.removeItem(at: tmpPath)
        try FileManager.default.copyItem(at: from, to: to)
      }
    )
  }
}

extension DependencyValues {
  var fileImport: FileImportClient {
    get { self[FileImportClient.self] }
    set { self[FileImportClient.self] = newValue }
  }
}

@MainActor
private func _importFile(from: URL, to: URL) async throws {
  let outputSampleRate = 16000.0
  let outputAudioFormat = try AVAudioFormat(standardFormatWithSampleRate: outputSampleRate, channels: 1).require()

  let sourceFile = try AVAudioFile(forReading: from)
  let format = sourceFile.processingFormat

  let sourceSettings = sourceFile.fileFormat.settings
  var outputSettings = sourceSettings
  outputSettings[AVSampleRateKey] = outputSampleRate

  let engine = AVAudioEngine()
  let player = AVAudioPlayerNode()

  engine.attach(player)

  engine.connect(player, to: engine.mainMixerNode, format: format)

  // The maximum number of frames the engine renders in any single render call.
  let maxFrames: AVAudioFrameCount = 4096
  try engine.enableManualRenderingMode(.offline, format: outputAudioFormat,
                                       maximumFrameCount: maxFrames)
 engine.prepare()
  try engine.start()
  player.play()

  // Schedule the source file.
  await player.scheduleFile(sourceFile, at: nil)

  // The output buffer to which the engine renders the processed data.
  let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                frameCapacity: engine.manualRenderingMaximumFrameCount)!

  let outputFile = try AVAudioFile(forWriting: to, settings: outputSettings)

  let outputLengthD = Double(sourceFile.length) * outputSampleRate / sourceFile.fileFormat.sampleRate
  let outputLength = Int64(ceil(outputLengthD)) // no sample left behind

  while engine.manualRenderingSampleTime < outputLength {
    let frameCount = outputLength - engine.manualRenderingSampleTime
    let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)

    let status = try engine.renderOffline(framesToRender, to: buffer)

    switch status {
    case .success:
      // The data rendered successfully. Write it to the output file.
      try outputFile.write(from: buffer)

    case .insufficientDataFromInputNode:
      // Applicable only when using the input node as one of the sources.
      break

    case .cannotDoInCurrentContext:
      // The engine couldn't render in the current render call.
      // Retry in the next iteration.
      break

    case .error:
      // An error occurred while rendering the audio.
      throw ErrorMessage("Error rendering audio")

    @unknown default:
      break
    }
  }

  // Stop the player node and engine.
  player.stop()
  engine.stop()
}
