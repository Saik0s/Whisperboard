import ComposableArchitecture
import Dependencies
import Foundation
import WhisperKit

// MARK: - RecordingTranscriptionStream

@DependencyClient
public struct RecordingTranscriptionStream: Sendable {
  public var startLiveTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<AudioFileStreamRecorder.State, Error> = { _ in .finished(throwing: nil) }
  public var loadModel: @Sendable (String) async throws -> AsyncThrowingStream<ModelLoadingStage, Error> = { _ in .finished(throwing: nil) }
  public var unloadModel: @Sendable () async throws -> Void = {}
  public var removeModel: @Sendable (String) async throws -> Void = { _ in }
  public var fetchModels: @Sendable () async throws -> Void = {}
  public var tokenIDToToken: @Sendable (Int) -> String = { _ in "" }
  public var startRecordingWithoutTranscription: @Sendable (_ fileURL: URL) async
    -> AsyncThrowingStream<AudioFileStreamRecorder.State, Error> = { _ in
      .finished(throwing: nil)
    }

  public var stopRecording: @Sendable () async -> Void = {}
  public var pauseRecording: @Sendable () async -> Void = {}
  public var resumeRecording: @Sendable () async -> Void = {}
}

// MARK: - RecordingTranscriptionStreamError

public enum RecordingTranscriptionStreamError: Error {
  case tokenizerUnavailable
}

// MARK: - ModelLoadingStage

@CasePathable
public enum ModelLoadingStage: Sendable, Equatable {
  case downloading(progress: Double)
  case prewarming
  case loading
  case completed
}

// MARK: - RecordingTranscriptionStream + DependencyKey

extension RecordingTranscriptionStream: DependencyKey {
  public static var liveValue: RecordingTranscriptionStream = {
    actor LiveTranscriptionResources {
      let audioProcessor: AudioProcessor
      let whisperKitInstance: WhisperKit
      var audioFileStreamRecorder: AudioFileStreamRecorder?

      init() async throws {
        self.audioProcessor = AudioProcessor()
        self.whisperKitInstance = try await WhisperKit(
          audioProcessor: audioProcessor,
          verbose: false,
          logLevel: .info,
          prewarm: false,
          load: false,
          download: false
        )
      }

      func setAudioFileStreamRecorder(_ recorder: AudioFileStreamRecorder) {
        self.audioFileStreamRecorder = recorder
      }
    }

    let resources = Task.synchronous {
      try await LiveTranscriptionResources()
    }

    let repoName = "argmaxinc/whisperkit-coreml"
    let localModelURL = URL.documentsDirectory.appending(component: "huggingface/models/\(repoName)")

    @Sendable func loadModelAsync(model: String, continuation: AsyncThrowingStream<ModelLoadingStage, Error>.Continuation) async {
      do {
        let localModelFiles = (try? FileManager.default.contentsOfDirectory(atPath: localModelURL.path())) ?? []
        logs.info("Local model files: \(localModelFiles)")
        let localModels = WhisperKit.formatModelFiles(localModelFiles)
        logs.info("Formatted local models: \(localModels)")

        var folder: URL = if localModels.contains(model) {
          localModelURL.appendingPathComponent(model)
        } else {
          try await WhisperKit.download(variant: model, from: repoName, progressCallback: { progress in
            continuation.yield(.downloading(progress: Double(round(100 * progress.fractionCompleted) / 100)))
          })
        }

        resources.whisperKitInstance.modelFolder = folder
        continuation.yield(.prewarming)
        do {
          try await resources.whisperKitInstance.prewarmModels()
          logs.info("Models prewarmed successfully. \(resources.whisperKitInstance.modelState)")
        } catch {
          logs.error("Failed to prewarm models: \(error.localizedDescription)")
          throw error
        }

        continuation.yield(.loading)
        do {
          try await resources.whisperKitInstance.loadModels()
          logs.info("Models loaded successfully. \(resources.whisperKitInstance.modelState)")
        } catch {
          logs.error("Failed to load models: \(error.localizedDescription)")
          throw error
        }

        continuation.yield(.completed)
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
    }

    return RecordingTranscriptionStream(
      startLiveTranscription: { fileURL in
        AsyncThrowingStream { continuation in
          Task {
            let recorder = AudioFileStreamRecorder(
              whisperKit: resources.whisperKitInstance,
              audioProcessor: resources.audioProcessor,
              decodingOptions: .realtime
            ) { newState in
              continuation.yield(newState)
            }

            await resources.setAudioFileStreamRecorder(recorder)

            do {
              try await recorder.startRecording(at: fileURL)
            } catch {
              continuation.finish(throwing: error)
              return
            }

            continuation.finish(throwing: nil)
          }

          continuation.onTermination = { _ in
            Task {
              await resources.audioFileStreamRecorder?.stopRecording()
            }
          }
        }
      },
      loadModel: { model in
        AsyncThrowingStream { continuation in
          Task {
            await loadModelAsync(model: model, continuation: continuation)
          }
        }
      },
      unloadModel: {
        await resources.whisperKitInstance.unloadModels()
      },
      removeModel: { model in
        let modelPath = localModelURL.appendingPathComponent(model)
        try FileManager.default.removeItem(at: modelPath)
      },
      fetchModels: {
        if FileManager.default.fileExists(atPath: localModelURL.path()) {
          do {
            let downloadedModels = try FileManager.default.contentsOfDirectory(atPath: localModelURL.path())
            logs.info("Downloaded models: \(downloadedModels)")
            let formattedDownloadedModels = WhisperKit.formatModelFiles(downloadedModels)
            logs.info("Formatted downloaded models: \(formattedDownloadedModels)")
            let remoteModels = try await WhisperKit.fetchAvailableModels(from: repoName)
            logs.info("Remote models: \(remoteModels)")
          } catch {
            print("Error: \(error.localizedDescription)")
          }
        }
      },
      tokenIDToToken: { tokenID in
        resources.whisperKitInstance.tokenizer?.convertIdToToken(tokenID) ?? ""
      },
      startRecordingWithoutTranscription: { url in
        AsyncThrowingStream { continuation in
          Task {
            let recorder = AudioFileStreamRecorder(
              whisperKit: resources.whisperKitInstance,
              audioProcessor: resources.audioProcessor,
              decodingOptions: .realtime,
              isTranscriptionEnabled: false,
              stateChangeCallback: { newState in
                continuation.yield(newState)
              }
            )

            await resources.setAudioFileStreamRecorder(recorder)

            Task {
              do {
                try await resources.audioFileStreamRecorder?.startRecording(at: url)
              } catch {
                continuation.finish(throwing: error)
              }
            }

            continuation.onTermination = { _ in
              Task {
                await resources.audioFileStreamRecorder?.stopRecording()
              }
            }
          }
        }
      },
      stopRecording: {
        await resources.audioFileStreamRecorder?.stopRecording()
      },
      pauseRecording: {
        await resources.audioFileStreamRecorder?.pauseRecording()
      },
      resumeRecording: {
        await resources.audioFileStreamRecorder?.resumeRecording()
      }
    )
  }()
}

extension DecodingOptions {
  static var realtime: DecodingOptions {
    DecodingOptions(
      verbose: false,
      task: .transcribe,
      language: nil,
      temperature: 0.0,
      temperatureIncrementOnFallback: 0.2,
      temperatureFallbackCount: 3,
      sampleLength: 224,
      topK: 5,
      usePrefillPrompt: false,
      usePrefillCache: false,
      skipSpecialTokens: true,
      withoutTimestamps: false,
      wordTimestamps: false,
      suppressBlank: true,
      supressTokens: nil,
      compressionRatioThreshold: 2.4,
      logProbThreshold: -1.0,
      firstTokenLogProbThreshold: nil,
      noSpeechThreshold: 0.3,
      concurrentWorkerCount: 1
    )
  }
}
