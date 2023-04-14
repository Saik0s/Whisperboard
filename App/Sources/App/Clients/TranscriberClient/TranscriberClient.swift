import AppDevUtils
import Combine
import Dependencies
import Foundation

typealias TranscriptionSegment = String

// MARK: - TranscriptionProgress

enum TranscriptionProgress {
  case loadingModel
  case started
  case newSegment(TranscriptionSegment)
  case finished(String)
  case error(Error)
}

// MARK: - TranscriberClient

struct TranscriberClient {
  var selectModel: @Sendable (_ model: VoiceModelType) -> Void
  var getSelectedModel: @Sendable () -> VoiceModelType

  var loadSelectedModel: @Sendable () async throws -> Void
  var unloadSelectedModel: @Sendable () -> Void

  var transcribeAudio: @Sendable (_ audioURL: URL, _ language: VoiceLanguage) -> AsyncStream<TranscriptionProgress>
  var transcriberState: @Sendable () -> TranscriberState
  var transcriberStateStream: @Sendable () -> AsyncStream<TranscriberState>

  var getAvailableLanguages: @Sendable () -> [VoiceLanguage]
}

// MARK: DependencyKey

extension TranscriberClient: DependencyKey {
  static var selectedModel: VoiceModelType {
    get {
      UserDefaults.standard.selectedModelName.flatMap { VoiceModelType(rawValue: $0) } ?? .default
    }
    set {
      UserDefaults.standard.selectedModelName = newValue.rawValue
    }
  }

  static let liveValue: TranscriberClient = {
    let impl = TranscriberImpl()

    return TranscriberClient(
      selectModel: { model in
        selectedModel = model
      },
      getSelectedModel: {
        if !FileManager.default.fileExists(atPath: selectedModel.localURL.path) {
          selectedModel = .default
        }
        return selectedModel
      },
      loadSelectedModel: {
        try await impl.loadModel(model: selectedModel)
      },
      unloadSelectedModel: {
        impl.unloadModel()
      },
      transcribeAudio: { audioURL, language in
        AsyncStream { continuation in
          Task.detached {
            do {
              continuation.yield(TranscriptionProgress.loadingModel)
              try await impl.loadModel(model: selectedModel)

              continuation.yield(TranscriptionProgress.started)
              let text = try await impl.transcribeAudio(audioURL, language: language) { segment in
                continuation.yield(.newSegment(segment))
              }

              continuation.yield(.finished(text))
            } catch {
              continuation.yield(.error(error))
            }

            continuation.onTermination = { termination in
              if termination == .cancelled {
                continuation.yield(.error(TranscriberError.cancelled))
              }
            }

            continuation.finish()
          }
        }
      },
      transcriberState: { impl.state.value },
      transcriberStateStream: { impl.state.asAsyncStream() },
      getAvailableLanguages: {
        [.auto] + impl.getAvailableLanguages().sorted { $0.name < $1.name }
      }
    )
  }()
}

// MARK: - TranscriberState

enum TranscriberState: Equatable {
  case idle
  case loadingModel
  case modelLoaded
  case transcribing
  case failed(EquatableErrorWrapper)
}

extension TranscriberState {
  var isTranscribing: Bool {
    switch self {
    case .transcribing:
      return true
    default:
      return false
    }
  }

  var isIdle: Bool {
    switch self {
    case .idle, .failed, .modelLoaded:
      return true
    default:
      return false
    }
  }
}

// MARK: - TranscriberError

enum TranscriberError: Error, CustomStringConvertible {
  case couldNotLocateModel
  case modelNotLoaded
  case notEnoughMemory(available: UInt64, required: UInt64)
  case cancelled

  var localizedDescription: String {
    switch self {
    case .couldNotLocateModel:
      return "Could not locate model"
    case .modelNotLoaded:
      return "Model not loaded"
    case let .notEnoughMemory(available, required):
      return "Not enough memory. Available: \(bytesToReadableString(bytes: available)), required: \(bytesToReadableString(bytes: required))"
    case .cancelled:
      return "Cancelled"
    }
  }

  var description: String {
    localizedDescription
  }
}

// MARK: - TranscriberImpl

final class TranscriberImpl {
  let state: CurrentValueSubject<TranscriberState, Never> = CurrentValueSubject(.idle)

  private var whisperContext: WhisperContext?
  private var model: VoiceModelType?

  func loadModel(model: VoiceModelType) async throws {
    if whisperContext != nil && model == self.model {
      log.verbose("Model already loaded")
      return
    } else if whisperContext != nil {
      unloadModel()
    }

    let memory = freeMemory()
    log.info("Available memory: \(bytesToReadableString(bytes: availableMemory()))")
    log.info("Free memory: \(bytesToReadableString(bytes: memory))")

    guard memory > model.memoryRequired else {
      throw TranscriberError.notEnoughMemory(available: memory, required: model.memoryRequired)
    }

    try await withCheckedThrowingContinuation { continuation in
      self.model = model
      state.value = .loadingModel
      do {
        log.verbose("Loading model...")
        whisperContext = try WhisperContext.createContext(path: model.localURL.path)
        state.value = .modelLoaded
        log.verbose("Loaded model \(model.fileName)")
        continuation.resume()
      } catch {
        state.value = .failed(error.equatable)
        continuation.resume(throwing: error)
      }
    }
  }

  func unloadModel() {
    log.verbose("Unloading model...")
    whisperContext = nil
    state.value = .idle
  }

  /// Transcribes the audio file at the given URL.
  /// Model should be loaded
  func transcribeAudio(_ audioURL: URL, language: VoiceLanguage, newSegmentCallback: @escaping (String) -> Void) async throws -> String {
    guard state.value == .modelLoaded, let whisperContext else {
      throw TranscriberError.modelNotLoaded
    }

    state.value = .transcribing

    do {
      log.verbose("Reading wave samples...")
      let data = try readAudioSamples(audioURL)

      log.verbose("Transcribing data...")
      try await whisperContext.fullTranscribe(samples: data, language: language, newSegmentCallback: newSegmentCallback)

      let text = await whisperContext.getTranscription()
      log.verbose("Done: \(text)")

      state.value = .modelLoaded

      return text
    } catch {
      state.value = .failed(error.equatable)
      log.error(error)
      throw error
    }
  }

  func getAvailableLanguages() -> [VoiceLanguage] {
    WhisperContext.getAvailableLanguages()
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

private extension UserDefaults {
  var selectedModelName: String? {
    get { string(forKey: #function) }
    set { set(newValue, forKey: #function) }
  }
}
