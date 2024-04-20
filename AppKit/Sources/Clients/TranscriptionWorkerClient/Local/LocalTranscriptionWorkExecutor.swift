import Dependencies
import Foundation

// MARK: - LocalTranscriptionError

enum LocalTranscriptionError: Error, LocalizedError {
  case notEnoughMemory(available: UInt64, required: UInt64)

  var errorDescription: String? {
    switch self {
    case let .notEnoughMemory(available, required):
      "Not enough memory to transcribe file. Available: \(bytesToReadableString(bytes: available)), required: \(bytesToReadableString(bytes: required))"
    }
  }
}

// MARK: - LocalTranscriptionWorkExecutor

final class LocalTranscriptionWorkExecutor: TranscriptionWorkExecutor {
  var currentWhisperContext: (context: WhisperContextProtocol, modelType: VoiceModelType, useGPU: Bool)? = nil
  var currentTaslId: UUID?

  private let updateTranscription: (_ transcription: Transcription) -> Void

  @Dependency(\.storage) var storage
  @Dependency(\.settings) var settings

  init(updateTranscription: @escaping (_ transcription: Transcription) -> Void) {
    self.updateTranscription = updateTranscription
  }

  func processTask(_ task: TranscriptionTask, updateTask: @escaping (TranscriptionTask) -> Void) async {
    currentTaslId = task.id
    defer { currentTaslId = nil }

    let initialSegments = task.segments
    var task: TranscriptionTask = task {
      didSet { updateTask(task) }
    }
    var transcription = Transcription(
      id: task.id,
      fileName: task.fileName,
      segments: task.segments,
      parameters: task.parameters,
      model: task.modelType
    ) {
      didSet {
        task.segments = transcription.segments
        updateTranscription(transcription)
      }
    }

    let fileURL = storage.audioFileURLWithName(task.fileName)

    do {
      transcription.status = .loading

      let useGPU = settings.getSettings().isUsingGPU
      let context: WhisperContextProtocol = try await resolveContextFor(useGPU: useGPU, task: task) { task = $0 }

      transcription.status = .progress(task.progress)

      for try await action in try context.fullTranscribe(audioFileURL: fileURL, params: task.parameters) {
        log.debug(action)
        var _transcription = transcription
        switch action {
        case let .newSegment(segment):
          _transcription.segments.append(segment)
          _transcription.status = .progress(task.progress)

        case let .progress(progress):
          log.debug("Progress: \(progress)")

        case let .error(error):
          _transcription.status = .error(message: error.localizedDescription)

        case .canceled:
          _transcription.status = .canceled

        case let .finished(segments):
          _transcription.segments = initialSegments + segments
          _transcription.status = .done(Date())
        }
        transcription = _transcription
      }
    } catch {
      transcription.status = .error(message: error.localizedDescription)
    }
  }

  func cancel(task: TranscriptionTask) {
    if task.id == currentTaslId {
      currentWhisperContext?.context.cancel()
    }
  }

  private func resolveContextFor(useGPU: Bool, task: TranscriptionTask,
                                 updateTask: (TranscriptionTask) -> Void) async throws -> WhisperContextProtocol {
    if let currentContext = currentWhisperContext, currentContext.modelType == task.modelType, currentContext.useGPU == useGPU {
      return currentContext.context
    } else {
      currentWhisperContext = nil
      let selectedModel = FileManager.default.fileExists(atPath: task.modelType.localURL.path) ? task.modelType : .default
      // Update model type in case it of fallback to default
      updateTask(task.with(\.modelType, setTo: selectedModel))

      let memory = freeMemoryAmount()
      log.info("Available memory: \(bytesToReadableString(bytes: availableMemory()))")
      log.info("Free memory: \(bytesToReadableString(bytes: memory))")

      guard memory > selectedModel.memoryRequired else {
        throw LocalTranscriptionError.notEnoughMemory(available: memory, required: selectedModel.memoryRequired)
      }

      let context = try WhisperContext(modelPath: selectedModel.localURL.path, useGPU: useGPU)
      currentWhisperContext = (context, selectedModel, useGPU)
      return context
    }
  }
}
