import AppDevUtils
import Dependencies
import Foundation

// MARK: - TranscriberClient

struct TranscriberClient {
  var loadModel: @Sendable (_ modelUrl: URL) async throws -> Void
  var unloadModel: () -> Void
  var transcribeAudio: @Sendable (_ audioURL: URL, _ modelUrl: URL) async throws -> String
}

// MARK: DependencyKey

extension TranscriberClient: DependencyKey {
  static let liveValue: TranscriberClient = {
    let impl = TranscriberImpl()

    return TranscriberClient(
      loadModel: { url in
        try await impl.loadModel(modelUrl: url)
      },
      unloadModel: {
        impl.unloadModel()
      },
      transcribeAudio: { audioURL, modelURL in
        try await impl.transcribeAudio(audioURL, modelURL)
      }
    )
  }()
}

// MARK: - TranscriberImpl

final class TranscriberImpl {
  var isLoadingModel = false
  var isModelLoaded = false
  var isTranscribing = false

  private enum LoadError: Error {
    case couldNotLocateModel
    case somethingWrong
  }

  private var whisperContext: WhisperContext?

  func loadModel(modelUrl: URL) async throws {
    try await withCheckedThrowingContinuation { continuation in
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

  func unloadModel() {
    isModelLoaded = false
    whisperContext = nil
  }

  func transcribeAudio(_ audioURL: URL, _ modelUrl: URL) async throws -> String {
    if !isModelLoaded || whisperContext == nil {
      try await loadModel(modelUrl: modelUrl)
    }

    guard isModelLoaded, let whisperContext else {
      throw LoadError.somethingWrong
    }

    isTranscribing = true
    defer { isTranscribing = false }

    log("Reading wave samples...")
    let data = try readAudioSamples(audioURL)
    log("Transcribing data...")
    await whisperContext.fullTranscribe(samples: data)
    let text = await whisperContext.getTranscription()
    log("Done: \(text)")
    return text
  }

  private func readAudioSamples(_ url: URL) throws -> [Float] {
    try decodeWaveFile(url)
  }
}

extension DependencyValues {
  var transcriber: TranscriberClient {
    get { self[TranscriberClient.self] }
    set { self[TranscriberClient.self] = newValue }
  }
}

func decodeWaveFile(_ url: URL) throws -> [Float] {
  let data = try Data(contentsOf: url)
  let floats = stride(from: 44, to: data.count, by: 2).map {
    data[$0 ..< $0 + 2].withUnsafeBytes {
      let short = Int16(littleEndian: $0.load(as: Int16.self))
      return max(-1.0, min(Float(short) / 32767.0, 1.0))
    }
  }
  return floats
}
