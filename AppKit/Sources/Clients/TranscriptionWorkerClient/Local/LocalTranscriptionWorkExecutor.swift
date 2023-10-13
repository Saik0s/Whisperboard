import Foundation

// MARK: - LocalTranscriptionError

enum LocalTranscriptionError: Error {
  case notEnoughMemory(available: UInt64, required: UInt64)
}

// MARK: - LocalTranscriptionWorkExecutor

final class LocalTranscriptionWorkExecutor: TranscriptionWorkExecutor {
  var currentWhisperContext: (context: WhisperContextProtocol, modelType: VoiceModelType)? = nil

  private let updateTranscription: (_ transcription: Transcription) -> Void

  init(updateTranscription: @escaping (_ transcription: Transcription) -> Void) {
    self.updateTranscription = updateTranscription
  }

  func processTask(_ task: TranscriptionTask, updateTask: @escaping (TranscriptionTask) -> Void) async {
    var task: TranscriptionTask = task {
      didSet { updateTask(task) }
    }
    var transcription = Transcription(id: task.id, fileName: task.fileName, parameters: task.parameters, model: task.modelType) {
      didSet { updateTranscription(transcription) }
    }

    do {
      transcription.status = .loading

      let context: WhisperContextProtocol = try await resolveContextFor(task: task) { task = $0 }
      let samples = try decodeWaveFile(task.fileURL)

      transcription.status = .progress(0.0)

      for await action in try await context.fullTranscribe(samples: samples, params: task.parameters) {
        log.debug(action)
        switch action {
        case let .newSegment(segment):
          transcription.segments.append(segment)
        case let .progress(progress):
          transcription.status = .progress(progress)
        case let .error(error):
          transcription.status = .error(message: error.localizedDescription)
        case .canceled:
          transcription.status = .canceled
        case let .finished(segments):
          transcription.segments = segments
          transcription.status = .done(Date())
        }
      }
    } catch {
      transcription.status = .error(message: error.localizedDescription)
    }
  }

  func cancel(task: TranscriptionTask) {
    currentWhisperContext?.context.cancel()
  }

  private func resolveContextFor(task: TranscriptionTask, updateTask: (TranscriptionTask) -> Void) async throws -> WhisperContextProtocol {
    if let currentContext = currentWhisperContext, currentContext.modelType == task.modelType {
      return currentContext.context
    } else {
      let selectedModel = FileManager.default.fileExists(atPath: task.modelType.localURL.path) ? task.modelType : .default
      // Update model type in case it of fallback to default
      updateTask(task.with(\.modelType, setTo: selectedModel))

      let memory = freeMemoryAmount()
      log.info("Available memory: \(bytesToReadableString(bytes: availableMemory()))")
      log.info("Free memory: \(bytesToReadableString(bytes: memory))")

      guard memory > selectedModel.memoryRequired else {
        throw LocalTranscriptionError.notEnoughMemory(available: memory, required: selectedModel.memoryRequired)
      }

      let context = try await WhisperContext.createFrom(modelPath: selectedModel.localURL.path)
      currentWhisperContext = (context, selectedModel)
      return context
    }
  }
}

private func decodeWaveFile(_ url: URL) throws -> [Float] {
  let data = try Data(contentsOf: url)
  let floats = stride(from: 44, to: data.count, by: 2).map {
    data[$0 ..< $0 + 2].withUnsafeBytes {
      let short = Int16(littleEndian: $0.load(as: Int16.self))
      return max(-1.0, min(Float(short) / 32767.0, 1.0))
    }
  }
  return floats
}
