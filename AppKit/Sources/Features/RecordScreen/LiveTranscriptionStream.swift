
import ComposableArchitecture
import Dependencies
import Foundation
import WhisperKit

// MARK: - LiveTranscriptionStream

@DependencyClient
public struct LiveTranscriptionStream {
  public var startLiveTranscription: @Sendable () async throws -> AsyncThrowingStream<String, Error> = { .finished(throwing: nil) }
  public var loadModel: @Sendable (String, Bool) async throws -> Void = { _, _ in }
  public var unloadModel: @Sendable () async throws -> Void = {}
  public var removeModel: @Sendable (String) async throws -> Void = { _ in }
  public var fetchModels: @Sendable () async throws -> Void = {}
}

enum LiveTranscriptionStreamError: Error {
  case tokenizerUnavailable
}

public extension LiveTranscriptionStream {
  static var liveValue: LiveTranscriptionStream = {
    let whisperKit: ActorIsolated<WhisperKit?> = ActorIsolated(nil)

    let localModelURL = URL.documentsDirectory.appending(component: "whisperkit")
    let repoName = "argmaxinc/whisperkit-coreml"

    return LiveTranscriptionStream(
      startLiveTranscription: {
        let whisperKitInstance = try await whisperKit.value.require()
        guard let tokenizer = whisperKitInstance.tokenizer else {
            throw LiveTranscriptionStreamError.tokenizerUnavailable
        }

        let decodingOptions = DecodingOptions(
            verbose: true,
            task: .transcribe,
            language: nil,
            temperature: 0.0,
            temperatureIncrementOnFallback: 0.2,
            temperatureFallbackCount: 3,
            topK: 5,
            usePrefillPrompt: false,
            usePrefillCache: false,
            skipSpecialTokens: false,
            withoutTimestamps: false,
            wordTimestamps: false,
            supressTokens: nil,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0,
            firstTokenLogProbThreshold: nil,
            noSpeechThreshold: 0.6,
            concurrentWorkerCount: 1
        )

        return AsyncThrowingStream { continuation in
            let audioStreamTranscriber = AudioStreamTranscriber(
                audioEncoder: whisperKitInstance.audioEncoder,
                featureExtractor: whisperKitInstance.featureExtractor,
                segmentSeeker: whisperKitInstance.segmentSeeker,
                textDecoder: whisperKitInstance.textDecoder,
                tokenizer: tokenizer,
                audioProcessor: whisperKitInstance.audioProcessor,
                decodingOptions: decodingOptions
            ) { oldState, newState in
                guard oldState.currentText != newState.currentText ||
                    oldState.unconfirmedSegments != newState.unconfirmedSegments ||
                    oldState.confirmedSegments != newState.confirmedSegments
                else {
                    return
                }
                for segment in newState.confirmedSegments {
                    continuation.yield(segment.text)
                }
                continuation.yield(newState.currentText)
            }

            Task {
                do {
                    try await audioStreamTranscriber.startStreamTranscription()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
      },
      loadModel: { model, redownload in
        let whisperKitInstance = try await WhisperKit(
          verbose: true,
          logLevel: .debug,
          prewarm: false,
          load: false,
          download: false
        )
        await whisperKit.withValue { $0 = whisperKitInstance }

        let localModels = (try? WhisperKit.formatModelFiles(FileManager.default.contentsOfDirectory(atPath: localModelURL.path()))) ?? []
        var folder: URL = if localModels.contains(model) && !redownload {
          localModelURL.appendingPathComponent(model)
        } else {
          try await WhisperKit.download(variant: model, from: repoName, progressCallback: { progress in
            print("Download progress: \(progress.fractionCompleted * 100)%")
          })
        }

        whisperKitInstance.modelFolder = folder
        do {
            try await whisperKitInstance.prewarmModels()
            logs.info("Models prewarmed successfully.")
        } catch {
            logs.error("Failed to prewarm models: \(error.localizedDescription)")
            throw error
        }

        do {
            try await whisperKitInstance.loadModels()
            logs.info("Models loaded successfully.")
        } catch {
            logs.error("Failed to load models: \(error.localizedDescription)")
            throw error
        }
      },
      unloadModel: {
        await whisperKit.withValue { $0 = nil }
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
      }
    )
  }()
}
