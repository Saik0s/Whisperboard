import AppDevUtils
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import os.log
import RecognitionKit
import SwiftUI

typealias FileName = String

// MARK: - TranscriberClient

struct TranscriberClient {
  /// Sets the voice model type for speech synthesis.
  ///
  /// - parameter model: The voice model type to use for speech synthesis. It can be one of the predefined values in
  /// `VoiceModelType` enum or a custom value.
  /// - note: This function is marked with `@Sendable` attribute to indicate that it can be safely called from concurrent
  /// contexts.
  var selectModel: @Sendable (_ model: VoiceModelType) -> Void
  /// Returns the selected voice model type.
  ///
  /// - returns: A `VoiceModelType` value that represents the current voice model selection.
  var getSelectedModel: @Sendable () -> VoiceModelType

  /// Unloads the currently selected 3D model from the scene.
  ///
  /// This function is marked as `@Sendable` to allow it to be called from concurrent contexts.
  ///
  /// - precondition: A model must be selected before calling this function.
  /// - postcondition: The selected model is removed from the scene and the selection is cleared.
  var unloadSelectedModel: @Sendable () -> Void

  /// Transcribes an audio file to text using the specified language and parallelism mode.
  ///
  /// - parameter audioURL: The URL of the audio file to transcribe.
  /// - parameter language: The language of the speech in the audio file.
  /// - parameter isParallel: A Boolean value indicating whether to use parallel processing for faster transcription.
  /// - returns: A `String` containing the transcription of the audio file.
  /// - throws: An error if the transcription fails or the audio file is invalid.
  var transcribeAudio: @Sendable (_ audioURL: URL, _ language: VoiceLanguage, _ isParallel: Bool) async throws -> String

  /// Returns a publisher that emits the transcription state for each file name.
  ///
  /// - parameter transcriptionStateStream: A publisher of type `AnyPublisher<[FileName: TranscriptionState], Never>`.
  /// - returns: A publisher that emits a dictionary of file names and their corresponding transcription states. The
  /// publisher never fails.
  var transcriptionStateStream: AsyncStream<[FileName: TranscriptionState]>

  /// Returns an array of available voice languages for text-to-speech.
  ///
  /// - returns: An array of `VoiceLanguage` values representing the supported languages.
  var getAvailableLanguages: @Sendable () -> [VoiceLanguage]
}

// MARK: DependencyKey

extension TranscriberClient: DependencyKey {
  /// Gets or sets the selected voice model type from the user defaults.
  ///
  /// - parameter selectedModel: A `VoiceModelType` value that represents the voice model chosen by the user.
  /// - returns: The current `VoiceModelType` value stored in the user defaults, or `.default` if none is found.
  static var selectedModel: VoiceModelType {
    get { UserDefaults.standard.selectedModelName.flatMap { VoiceModelType(rawValue: $0) } ?? .default }
    set { UserDefaults.standard.selectedModelName = newValue.rawValue }
  }

  /// Returns a `TranscriberClient` instance that can transcribe audio files using a selected model.
  ///
  /// - parameter selectModel: A closure that sets the selected model to the given parameter.
  /// - parameter getSelectedModel: A closure that returns the current selected model, or the default one if it does not
  /// exist.
  /// - parameter unloadSelectedModel: A closure that unloads the current selected model from memory.
  /// - parameter transcribeAudio: A closure that takes an audio URL, a language, and a boolean indicating whether to use
  /// parallel decoding, and returns a string containing the transcription. The closure also updates the transcription
  /// state for the given audio file periodically.
  /// - parameter transcriptionStateStream: A publisher that emits the current transcription states for all audio files
  /// being transcribed.
  /// - parameter getAvailableLanguages: A closure that returns an array of available languages for transcription,
  /// including `.auto` for automatic detection.
  /// - returns: A `TranscriberClient` object with the specified closures.
  static let liveValue: TranscriberClient = {
    let impl = TranscriberImpl()
    @Dependency(\.transcriptionsStream) var transcriptionsStream: TranscriptionsStream

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

      unloadSelectedModel: {
        impl.unloadModel()
      },

      transcribeAudio: { audioURL, language, isParallel in
        let fileName = audioURL.lastPathComponent
        log.verbose("Transcribing \(fileName)...")

        for await state in impl.transcriptionPipeline(audioURL, language: language, isParallel: isParallel) {
          transcriptionsStream.updateState(fileName: fileName, state: state)
        }

        let current = transcriptionsStream.state(for: fileName)
        if let text = current?.finalText {
          transcriptionsStream.updateState(fileName: fileName, state: nil)
          return text
        } else {
          let error = current?.error ?? TranscriberError.cancelled
          transcriptionsStream.updateStateKey(fileName: fileName, keyPath: \TranscriptionState.error, value: error)
          throw error
        }
      },

      transcriptionStateStream: transcriptionsStream.asyncStream,

      getAvailableLanguages: {
        [.auto] + WhisperContext.getAvailableLanguages().sorted { $0.name < $1.name }
      }
    )
  }()
}

// MARK: - TranscriberImpl

final class TranscriberImpl {
  /// A private property that stores the current whisper context.
  ///
  /// A whisper context is an object that contains information about the current state of a whisper conversation, such as
  /// the sender, receiver, message, and timestamp. A whisper context is used to handle whisper messages and events in a
  /// consistent and secure way.
  private var whisperContext: WhisperContext?
  /// A private property that holds the voice model type.
  ///
  /// - note: This property is optional and may be nil if the voice model is not set.
  private var model: VoiceModelType?

  /// Loads a voice model from a local URL and creates a whisper context.
  ///
  /// - parameter model: The type of voice model to load.
  /// - throws: A `TranscriberError.notEnoughMemory` error if there is not enough free memory to load the model.
  /// - note: If a whisper context already exists and the model is different from the current one, the existing context is
  /// unloaded before loading the new model.
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

    self.model = model

    log.verbose("Loading model...")
    whisperContext = try WhisperContext.createContext(path: model.localURL.path)
    log.verbose("Loaded model \(model.fileName)")
  }

  /// Unloads the current model and clears the whisper context.
  ///
  /// - note: This function is asynchronous and uses a `Task` to perform the unloading operation.
  /// - postcondition: The `whisperContext` property is set to `nil` after this function is called.
  func unloadModel() {
    log.verbose("Unloading model...")
    whisperContext = nil
  }

  /// Transcribes an audio file into text using the Whisper context.
  ///
  /// - parameter audioURL: The URL of the audio file to transcribe.
  /// - parameter language: The language of the voice in the audio file.
  /// - parameter isParallel: A flag indicating whether to use parallel processing for faster transcription.
  /// - parameter newSegmentCallback: A closure that is called whenever a new segment of transcription is available.
  /// - throws: A `TranscriberError` if the model is not loaded or the transcription fails.
  /// - returns: A `String` containing the full transcription of the audio file.
  func transcriptionPipeline(
    _ audioURL: URL,
    language: VoiceLanguage,
    isParallel: Bool
  ) -> AsyncStream<TranscriptionState> {
    AsyncStream { continuation in
      Task {
        var state = TranscriptionState() {
          didSet { continuation.yield(state) }
        }

        do {
          state.progress = .loadingModel
          try await loadModel(model: TranscriberClient.selectedModel)

          guard let whisperContext else {
            throw TranscriberError.modelNotLoaded
          }

          log.verbose("Reading wave samples...")
          let data = try readAudioSamples(audioURL)

          log.verbose("Transcribing data...")
          state.progress = .transcribing([])
          try await whisperContext.fullTranscribe(samples: data, language: language, isParallel: isParallel) { segment in
            state.segments.append(segment)
          }

          let text = try await whisperContext.getTranscription()
          log.verbose("Done: \(text)")

          state.finalText = text
        } catch {
          log.error("Transcription failed: \(error)")
          state.progress = .error(error as? TranscriberError ?? .cancelled)
        }

        continuation.finish()
      }
    }
  }

  /// Reads audio samples from a wave file and returns them as an array of floats.
  ///
  /// - parameter url: The URL of the wave file to read from.
  /// - throws: An error if the wave file cannot be decoded or is not supported.
  /// - returns: An array of floats representing the audio samples.
  private func readAudioSamples(_ url: URL) throws -> [Float] {
    try decodeWaveFile(url)
  }
}

/// A property that manages the transcription service for the receiver.
///
/// You can use this property to get or set the `TranscriberClient` instance that performs speech recognition and
/// transcription for the receiver. The `TranscriberClient` instance is stored in the receiver's storage and can be
/// shared among multiple receivers.
extension DependencyValues {
  /// A computed property that accesses or sets the `TranscriberClient` instance associated with the receiver.
  ///
  /// - get: Returns the `TranscriberClient` instance stored in the receiver's storage.
  /// - set: Stores the given `TranscriberClient` instance in the receiver's storage.
  var transcriber: TranscriberClient {
    get { self[TranscriberClient.self] }
    set { self[TranscriberClient.self] = newValue }
  }
}

/// Decodes a wave file from a given URL and returns an array of floats representing the audio samples.
///
/// - parameter url: The URL of the wave file to decode.
/// - throws: An error if the data cannot be read from the URL or if the file format is invalid.
/// - returns: An array of floats in the range [-1.0, 1.0] corresponding to the audio samples in the wave file. The
/// array has a length of (data.count - 44) / 2, where data.count is the number of bytes in the file. The first 44 bytes
/// are skipped as they contain the wave header. Each pair of bytes is converted to a float using little-endian encoding
/// and normalized by dividing by 32767.0.
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
  /// Gets or sets the name of the selected model in the user defaults.
  ///
  /// - note: The key for storing and retrieving the name is the function name itself.
  var selectedModelName: String? {
    get { string(forKey: #function) }
    set { set(newValue, forKey: #function) }
  }
}
