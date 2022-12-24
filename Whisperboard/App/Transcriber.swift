//
// Created by Igor Tarasenko on 24/12/2022.
//

import Foundation

final class Transcriber {
  var isLoadingModel = false
  var isModelLoaded = false
  var isTranscribing = false

  private enum LoadError: Error {
    case couldNotLocateModel
    case somethingWrong
  }

  private var modelUrl: URL? {
    Bundle.main.url(forResource: "ggml-tiny.en", withExtension: "bin")
  }

  private var whisperContext: WhisperContext?

  func loadModel() async throws {
    guard let modelUrl else {
      log("Could not locate model")
      throw LoadError.couldNotLocateModel
    }

    return try await withCheckedThrowingContinuation { continuation in
      isLoadingModel = true
      do {
        log("Loading model...")
        whisperContext = try WhisperContext.createContext(path: modelUrl.path)
        isModelLoaded = true
        log("Loaded model \(modelUrl.lastPathComponent)")
        continuation.resume()
      } catch {
        continuation.resume(throwing: error)
      }
      isLoadingModel = false
    }
  }

  func transcribeAudio(_ url: URL) async throws -> String {
    guard isModelLoaded, let whisperContext else {
      throw LoadError.somethingWrong
    }

    isTranscribing = true
    defer { isTranscribing = false }

    log("Reading wave samples...")
    let data = try readAudioSamples(url)
    log("Transcribing data...")
    await whisperContext.fullTranscribe(samples: data)
    let text = await whisperContext.getTranscription()
    log("Done: \(text)")
    return text
  }

  private func readAudioSamples(_ url: URL) throws -> [Float] {
    // stopPlayback()
    // try startPlayback(url)
    return try decodeWaveFile(url)
  }
}

func decodeWaveFile(_ url: URL) throws -> [Float] {
  let data = try Data(contentsOf: url)
  let floats = stride(from: 44, to: data.count, by: 2).map {
    return data[$0..<$0 + 2].withUnsafeBytes {
      let short = Int16(littleEndian: $0.load(as: Int16.self))
      return max(-1.0, min(Float(short) / 32767.0, 1.0))
    }
  }
  return floats
}
