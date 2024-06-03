import Common
import ComposableArchitecture
import Dependencies
import Foundation
import WhisperKit

// MARK: - LiveTranscriptionUpdate

public enum LiveTranscriptionUpdate {
  case transcription(TranscriptionStream.State)
  case recording(RecordingStream.State)
}

// MARK: - ModelStatus

public struct ModelStatus {
  public let model: String
  public let isDownloaded: Bool
  public let isSelected: Bool

  public init(model: String, isDownloaded: Bool, isSelected: Bool) {
    self.model = model
    self.isDownloaded = isDownloaded
    self.isSelected = isSelected
  }
}

// MARK: - RecordingTranscriptionStream

@DependencyClient
public struct RecordingTranscriptionStream: Sendable {
  public var startLiveTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<LiveTranscriptionUpdate, Error> = { _ in .finished(throwing: nil) }

  public var startRecordingWithoutTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<RecordingStream.State, Error> = { _ in .finished(throwing: nil) }

  public var startFileTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<TranscriptionStream.State, Error> = { _ in .finished(throwing: nil) }

  public var stopRecording: @Sendable () async -> Void = {}
  public var pauseRecording: @Sendable () async -> Void = {}
  public var resumeRecording: @Sendable () async -> Void = {}

  public var fetchModels: @Sendable () async throws -> [ModelStatus] = { [] }
  public var loadModel: @Sendable (String) -> AsyncStream<ModelLoadingStage> = { _ in .finished }
  public var deleteModel: @Sendable (String) async throws -> Void = { _ in }
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
        try await container.startFileTranscription(fileURL)
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
      loadModel: { model in
        container.loadModel(model)
      },
      deleteModel: { model in
        try await container.deleteModel(model)
      }
    )
  }()
}

// MARK: - RecordingTranscriptionStreamContainer

private final class RecordingTranscriptionStreamContainer {
  let audioProcessor: AudioProcessor = .init()
  lazy var recordingStream: RecordingStream = .init(audioProcessor: audioProcessor)
  lazy var transcriptionStream: TranscriptionStream = .init(audioProcessor: audioProcessor)

  func startLiveTranscription(_ fileURL: URL) async throws -> AsyncThrowingStream<LiveTranscriptionUpdate, Error> {
    AsyncThrowingStream { continuation in
      let task = Task { [weak self] in
        guard let self else { return }

        do {
          async let recordingResult: Void = recordingStream.startRecording(at: fileURL) { state in
            continuation.yield(LiveTranscriptionUpdate.recording(state))
          }
          async let transcriptionResult: Void = transcriptionStream.startRealtimeLoop(callback: { state in
            continuation.yield(LiveTranscriptionUpdate.transcription(state))
          })

          try await recordingResult
          try await transcriptionResult

          continuation.finish(throwing: nil)
        } catch {
          logs.error("Failed to start live transcription \(error)")
          continuation.finish(throwing: error)
        }

        await recordingStream.stopRecording()
        await transcriptionStream.stopRealtimeLoop()
        await transcriptionStream.resetState()
      }

      continuation.onTermination = { _ in
        Task { [weak self] in
          await self?.recordingStream.stopRecording()
          await self?.transcriptionStream.stopRealtimeLoop()
          await self?.transcriptionStream.resetState()
          task.cancel()
        }
      }
    }
  }

  func startRecordingWithoutTranscription(_ fileURL: URL) async throws -> AsyncThrowingStream<RecordingStream.State, Error> {
    AsyncThrowingStream { continuation in
      let task = Task { [weak self] in
        do {
          try await self?.recordingStream.startRecording(at: fileURL) { state in
            continuation.yield(state)
          }
          continuation.finish(throwing: nil)
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

  func startFileTranscription(_ fileURL: URL) async throws -> AsyncThrowingStream<TranscriptionStream.State, Error> {
    AsyncThrowingStream { continuation in
      let task = Task { [weak self, audioProcessor] in
        do {
          let audioBuffer = try await AudioProcessor.loadAudio(at: [fileURL.path()]).first.require().get()
          audioProcessor.processBuffer(audioBuffer)
          try await self?.transcriptionStream.startRealtimeLoop(shouldStopWhenNoSamplesLeft: true) { state in
            continuation.yield(state)
          }
          continuation.finish(throwing: nil)
        } catch {
          logs.error("Failed to start file transcription \(error)")
          continuation.finish(throwing: error)
        }

        await self?.transcriptionStream.stopRealtimeLoop()
      }

      continuation.onTermination = { _ in
        Task { [weak self] in
          await self?.transcriptionStream.stopRealtimeLoop()
          task.cancel()
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

  func fetchModels() async throws -> [ModelStatus] {
    try await transcriptionStream.fetchModels()
    let state = await transcriptionStream.state
    return state.availableModels.map { model in
      ModelStatus(
        model: model,
        isDownloaded: state.localModels.contains(model),
        isSelected: state.selectedModel == model
      )
    }
  }

  func loadModel(_ model: String) -> AsyncStream<ModelLoadingStage> {
    let (stream, continuation) = AsyncStream<ModelLoadingStage>.makeStream()
    Task { [weak self] in
      guard let self else { return }

      let task = Task { [weak self] in
        guard let self else { return }

        while true {
          let state = await self.transcriptionStream.state
          continuation.yield(.inProgress(Double(state.loadingProgressValue), state.modelState))
          try await Task.sleep(for: .seconds(0.3))
        }
      }

      do {
        try await self.transcriptionStream.loadModel(model)
        task.cancel()
        let state = await self.transcriptionStream.state
        continuation.yield(.success(state.modelState))
      } catch {
        logs.error("Failed to load model \(error)")
        task.cancel()
        let state = await self.transcriptionStream.state
        continuation.yield(.failure(error.equatable, state.modelState))
      }

      continuation.finish()
    }
    return stream
  }

  func deleteModel(_ model: String) async throws {
    try await transcriptionStream.deleteModel(model)
  }
}

// MARK: - ModelLoadingStage

public enum ModelLoadingStage: Equatable {
  case idle
  case inProgress(Double, ModelState)
  case success(ModelState)
  case failure(EquatableError, ModelState)
}

public extension ModelLoadingStage {
  var isSuccess: Bool {
    switch self {
    case .success(_): return true
    default: return false
    }
  }
}

// MARK: - ModelLoadingStageError

public enum ModelLoadingStageError: Error {
  case modelNotLoaded
}

public extension ModelState {
  func asModelLoadingStage(progress: Double) -> ModelLoadingStage {
    switch self {
    case .downloaded: .success(self)
    case .downloading: .inProgress(progress, self)
    case .loaded: .success(self)
    case .loading: .inProgress(progress, self)
    case .prewarmed: .success(self)
    case .prewarming: .inProgress(progress, self)
    case .unloaded: .failure(ModelLoadingStageError.modelNotLoaded.equatable, self)
    case .unloading: .inProgress(progress, self)
    }
  }
}
