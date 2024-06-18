import Common
import ComposableArchitecture
import Dependencies
import Foundation
import WhisperKit

// MARK: - RecordingTranscriptionStream

@DependencyClient
public struct RecordingTranscriptionStream: Sendable {
  public var startRecording: @Sendable (_ fileURL: URL) async -> AsyncThrowingStream<RecordingStream.State, Error> = { _ in .finished() }
  public var readAndProcessAudioFile: @Sendable (_ fileURL: URL) async throws -> Void = { _ in }
  public var startLiveTranscription: @Sendable () async -> AsyncThrowingStream<TranscriptionStream.State, Error> = { .finished() }
  public var startBufferTranscription: @Sendable () async -> AsyncThrowingStream<TranscriptionStream.State, Error> = { .finished() }

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
      readAndProcessAudioFile: { fileURL in
        try await container.readAndProcessAudioFile(fileURL)
      },
      startLiveTranscription: {
        await container.startTranscriptionLoop()
      },
      startBufferTranscription: {
        await container.startBufferTranscription()
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
  var recordingStream: RecordingStream?
  var transcriptionStream: TranscriptionStream?

  func startRecording(_ fileURL: URL) -> AsyncThrowingStream<RecordingStream.State, Error> {
    AsyncThrowingStream { [weak self] continuation in
      Task { [weak self] in
        guard let self else { return }

        do {
          let recordingStream = RecordingStream(audioProcessor: audioProcessor)
          await setRecordingStream(recordingStream)
          continuation.onTermination = { _ in
            Task {
              await recordingStream.stopRecording()
              await self.setRecordingStream(nil)
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

  func readAndProcessAudioFile(_ fileURL: URL) async throws {
    let audioBuffer = try await AudioProcessor.loadAudio(at: [fileURL.path()]).first.require().get()
    logs.debug("Loaded audio buffer from file: \(fileURL), buffer size: \(audioBuffer.count) samples")

    audioProcessor.processBuffer(audioBuffer)
  }

  func startTranscriptionLoop() -> AsyncThrowingStream<TranscriptionStream.State, Error> {
    AsyncThrowingStream { [weak self] continuation in
      Task { [weak self] in
        guard let self else { return }

        do {
          let transcriptionStream = TranscriptionStream(audioProcessor: audioProcessor)
          await setTranscriptionStream(transcriptionStream)
          continuation.onTermination = { [self] _ in
            Task {
              await transcriptionStream.stopRealtimeLoop()
              await self.setTranscriptionStream(nil)
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

  func startBufferTranscription() -> AsyncThrowingStream<TranscriptionStream.State, Error> {
    AsyncThrowingStream { [weak self] continuation in
      Task { [weak self] in
        guard let self else { return }

        do {
          let transcriptionStream = TranscriptionStream(audioProcessor: audioProcessor)
          await setTranscriptionStream(transcriptionStream)
          continuation.onTermination = { _ in
            Task {
              await transcriptionStream.stopRealtimeLoop()
              await self.setTranscriptionStream(nil)
            }
          }

          try await transcriptionStream.transcribeCurrentBufferVADChunked { state in
            continuation.yield(state)
          }
          continuation.finish()
        } catch {
          logs.error("Failed to start file transcription \(error)")
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func stopRecording() async {
    await recordingStream?.stopRecording()
    await transcriptionStream?.stopRealtimeLoop()
  }

  func pauseRecording() async {
    await recordingStream?.pauseRecording()
  }

  func resumeRecording() async {
    await recordingStream?.resumeRecording()
  }

  func fetchModels() async throws -> [Model] {
    let transcriptionStream = transcriptionStream ?? TranscriptionStream(audioProcessor: audioProcessor)
    self.transcriptionStream = transcriptionStream
    try await transcriptionStream.fetchModels()
    return await getModelInfos()
  }

  func loadModel(_ model: String, progressCallback: @escaping (Double) -> Void) async throws {
    logs.debug("Starting to load model: \(model)")
    let transcriptionStream = transcriptionStream ?? TranscriptionStream(audioProcessor: audioProcessor)
    self.transcriptionStream = transcriptionStream
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
    let transcriptionStream = transcriptionStream ?? TranscriptionStream(audioProcessor: audioProcessor)
    self.transcriptionStream = transcriptionStream
    try await transcriptionStream.deleteModel(model)
  }

  func deleteAllModels() async throws {
    let modelDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("models")
    try FileManager.default.removeItem(at: modelDirectoryURL)
  }

  private func getModelInfos() async -> [Model] {
    let transcriptionStream = transcriptionStream ?? TranscriptionStream(audioProcessor: audioProcessor)
    self.transcriptionStream = transcriptionStream
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

  private func setRecordingStream(_ recordingStream: RecordingStream?) {
    self.recordingStream = recordingStream
  }

  private func setTranscriptionStream(_ transcriptionStream: TranscriptionStream?) {
    self.transcriptionStream = transcriptionStream
  }
}
