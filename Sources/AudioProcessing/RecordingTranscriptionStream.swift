import Common
import ComposableArchitecture
import Dependencies
import Foundation
import WhisperKit

// MARK: - RecordingTranscriptionStream

@DependencyClient
public struct RecordingTranscriptionStream: Sendable {
  public var startRecording: @Sendable (_ fileURL: URL) async -> AsyncThrowingStream<RecordingStream.State, Error> = { _ in .finished() }
  public var startLiveTranscription: @Sendable () async -> AsyncThrowingStream<TranscriptionStream.State, Error> = { .finished() }
  public var transcribeAudioFile: @Sendable (URL, @escaping (TranscriptionProgress, Double) -> Bool?) async throws -> TranscriptionResult = { _, _ in
    throw NSError(domain: "RecordingTranscriptionStream", code: 0, userInfo: nil)
  }

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
      startRecording: { fileURL in
        await container.startRecording(fileURL)
      },
      startLiveTranscription: {
        await container.startTranscriptionLoop()
      },
      transcribeAudioFile: { fileURL, callback in
        try await container.transcribeAudioFile(fileURL, callback: callback)
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

private actor RecordingTranscriptionStreamContainer {
  let audioProcessor: AudioProcessor = .init()
  lazy var recordingStream = RecordingStream(audioProcessor: audioProcessor)
  lazy var transcriptionStream = TranscriptionStream(audioProcessor: audioProcessor)

  func startRecording(_ fileURL: URL) -> AsyncThrowingStream<RecordingStream.State, Error> {
    AsyncThrowingStream { [weak self] continuation in
      Task { [weak self] in
        guard let self else { return }

        do {
          await recordingStream.resetState()
          continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
              await self?.recordingStream.stopRecording()
            }
          }
          try await recordingStream.startRecording(at: fileURL) { state in
            continuation.yield(state)
          }
          continuation.finish()
        } catch {
          logs.error("Failed to perform recording \(error)")
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func startTranscriptionLoop() -> AsyncThrowingStream<TranscriptionStream.State, Error> {
    AsyncThrowingStream { [weak self] continuation in
      Task { [weak self] in
        guard let self else { return }

        do {
          await transcriptionStream.resetState()
          continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
              await self?.transcriptionStream.stopRealtimeLoop()
            }
          }
          try await transcriptionStream.startRealtimeLoop { state in
            continuation.yield(state)
          }
          continuation.finish()
        } catch {
          logs.error("Failed to perform transcription \(error)")
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func transcribeAudioFile(_ fileURL: URL, callback: @escaping (TranscriptionProgress, Double) -> Bool?) async throws -> TranscriptionResult {
    try await transcriptionStream.transcribeAudioFile(fileURL, callback: callback)
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

    repeat {
      let progress = await transcriptionStream.state.loadingProgressValue
      let state = await transcriptionStream.state.modelState
      logs.debug("Model loading progress: \(progress * 100)% state: \(state)")
      progressCallback(Double(progress))
      try? await Task.sleep(for: .seconds(0.3))
    } while await transcriptionStream.state.modelState != .loaded

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
