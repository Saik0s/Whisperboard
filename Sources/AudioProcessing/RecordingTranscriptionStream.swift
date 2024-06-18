import Common
import ComposableArchitecture
import Dependencies
import Foundation
import WhisperKit

// MARK: - RecordingTranscriptionStream

@DependencyClient
public struct RecordingTranscriptionStream: Sendable {
  public var startLiveTranscription: @Sendable (_ fileURL: URL) async throws
  -> AsyncThrowingStream<TranscriptionStream.State, Error> = { _ in .finished(throwing: nil) }

  public var startRecordingWithoutTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<RecordingStream.State, Error> = { _ in .finished(throwing: nil) }

  public var startFileTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<TranscriptionStream.State, Error> = { _ in .finished(throwing: nil) }

  public var stopRecording: @Sendable () async -> Void = {}
  public var pauseRecording: @Sendable () async -> Void = {}
  public var resumeRecording: @Sendable () async -> Void = {}

  public var fetchModels: @Sendable () async throws -> [Model] = { [] }
  public var loadModel: @Sendable (String, @escaping (Double) -> Void) async throws -> Void = { _, _ in }
  public var deleteModel: @Sendable (String) async throws -> Void = { _ in }
  public var recommendedModels: @Sendable () -> (default: String, disabled: [String]) = { (default: "", disabled: []) }
  public var deleteAllModels: @Sendable () async throws -> Void = {}
}

// MARK: DependencyKey

extension RecordingTranscriptionStream: DependencyKey {
  public static var liveValue: RecordingTranscriptionStream = {
    let container = RecordingTranscriptionStreamContainer()

    return RecordingTranscriptionStream(
      startLiveTranscription: { fileURL in
        try await container.startLiveTranscription(fileURL)
      },
      startRecordingWithoutTranscription: { fileURL in
        try await container.startRecordingWithoutTranscription(fileURL)
      },
      startFileTranscription: { fileURL in
        container.startFileTranscription(fileURL)
      },
      stopRecording: {
        await container.stopRecording()
      },
      pauseRecording: {
        await container.pauseRecording()
      },
      resumeRecording: {
        await container.resumeRecording()
      },
      fetchModels: {
        try await container.fetchModels()
      },
      loadModel: { model, progressCallback in
        try await container.loadModel(model, progressCallback: progressCallback)
      },
      deleteModel: { model in
        try await container.deleteModel(model)
      },
      recommendedModels: {
        WhisperKit.recommendedModels()
      },
      deleteAllModels: {
        try await container.deleteAllModels()
      }
    )
  }()
}

// MARK: - RecordingTranscriptionStreamContainer

private final class RecordingTranscriptionStreamContainer {
  let audioProcessor: AudioProcessor = .init()

  func startTranscriptionLoop() -> AsyncThrowingStream<TranscriptionStream.State, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let transcriptionStream = TranscriptionStream(audioProcessor: audioProcessor)
          try await transcriptionStream.startRealtimeLoop(callback: { state in
            continuation.yield(state)
          })
          continuation.finish()
        } catch {
          logs.error("Failed to start live transcription \(error)")
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func startRecording(_ fileURL: URL) -> AsyncThrowingStream<RecordingStream.State, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let recordingStream = RecordingStream(audioProcessor: audioProcessor)
          try await self?.recordingStream.startRecording(at: fileURL) { state in
            continuation.yield(state)
          }
          continuation.finish()
        } catch {
          logs.error("Failed to start recording without transcription \(error)")
          continuation.finish(throwing: error)
        }

        await self?.recordingStream.stopRecording()
      }

      continuation.onTermination = { _ in
        Task { [weak self] in
          await self?.recordingStream.stopRecording()
          task.cancel()
        }
      }
    }
  }

  func startFileTranscription(_ fileURL: URL) -> AsyncThrowingStream<TranscriptionStream.State, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          logs.debug("Starting file transcription for URL: \(fileURL)")

          let audioBuffer = try await AudioProcessor.loadAudio(at: [fileURL.path()]).first.require().get()
          logs.debug("Loaded audio buffer from file: \(fileURL), buffer size: \(audioBuffer.count) samples")

          audioProcessor.processBuffer(audioBuffer)

          try await transcriptionStream.transcribeCurrentBufferVADChunked { state in
            continuation.yield(state)
          }
          continuation.finish(throwing: nil)
        } catch {
          logs.error("Failed to start file transcription \(error)")
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { reason in
        if case .cancelled = reason {
          task.cancel()
        }
        Task { [weak self] in
          await self?.transcriptionStream.stopRealtimeLoop()
        }
      }
    }
  }

  func stopRecording() async {
    await recordingStream.stopRecording()
    await transcriptionStream.stopRealtimeLoop()
  }

  func pauseRecording() async {
    await recordingStream.pauseRecording()
  }

  func resumeRecording() async {
    await recordingStream.resumeRecording()
  }

  func fetchModels() async throws -> [Model] {
    try await transcriptionStream.fetchModels()
    return await getModelInfos()
  }

  func loadModel(_ model: String, progressCallback: @escaping (Double) -> Void) async throws {
    logs.debug("Starting to load model: \(model)")
    async let loadModelTask: Void = transcriptionStream.loadModel(model)

    while await transcriptionStream.state.modelState != .loaded {
      let progress = await transcriptionStream.state.loadingProgressValue
      let state = await transcriptionStream.state.modelState
      logs.debug("Model loading progress: \(progress * 100)% state: \(state)")
      progressCallback(Double(progress))
      try? await Task.sleep(for: .seconds(0.3))
    }

    logs.debug("Model \(model) loaded successfully")
    try await loadModelTask
  }

  func deleteModel(_ model: String) async throws {
    try await transcriptionStream.deleteModel(model)
  }

  func deleteAllModels() async throws {
    let modelDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("models")
    try FileManager.default.removeItem(at: modelDirectoryURL)
  }

  private func getModelInfos() async -> [Model] {
    let state = await transcriptionStream.state
    let (defaultModel, disabledModels) = WhisperKit.recommendedModels()
    return state.availableModels.map { name in
      Model(
        name: name,
        isLocal: state.localModels.contains(name),
        isDefault: name == defaultModel,
        isDisabled: disabledModels.contains(name)
      )
    }
  }
}
