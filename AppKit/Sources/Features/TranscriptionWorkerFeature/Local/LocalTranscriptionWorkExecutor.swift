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
  var currentTaskID: TranscriptionTask.ID?

  init() {}

  func process(task: TranscriptionTaskEnvelope) async {
    currentTaskID = await task.id
    defer { currentTaskID = nil }

    await MainActor.run {
      if task.recording.transcription?.id != task.id {
        task.recording.transcription = Transcription(id: task.id, fileName: task.fileName, parameters: task.parameters, model: task.modelType)
      }
    }

    do {
      await MainActor.run {
        task.recording.transcription?.status = .loading
      }

      let useGPU = await task.task.settings.isUsingGPU
      let context: WhisperContextProtocol = try await resolveContextFor(useGPU: useGPU, task: task)

      await MainActor.run {
        task.recording.transcription?.status = .progress(task.progress)
      }

      let fileURL = await task.recording.fileURL
      var parameters = await task.parameters
      parameters.offsetMilliseconds = await Int(task.offset)

      for try await action in context.fullTranscribe(audioFileURL: fileURL, params: parameters) {
        logs.debug("Received WhisperAction: \(action)")
        switch action {
        case let .newSegment(segment):
          if await segment.startTime >= (task.recording.transcription?.segments.last?.endTime ?? 0) {
            logs.debug("Segment start time is not after the last segment end time")
          }
          await MainActor.run {
            task.recording.transcription?.segments.append(segment)
            task.recording.transcription?.status = .progress(task.progress)
          }

        case let .progress(progress):
          logs.debug("Progress: \(progress)")

        case let .error(error):
          await MainActor.run {
            task.recording.transcription?.status = .error(message: error.localizedDescription)
          }

        case .canceled:
          await MainActor.run {
            task.recording.transcription?.status = .canceled
          }

        case .finished:
          await MainActor.run {
            task.recording.transcription?.status = .done(Date())
          }
        }
      }
    } catch {
      await MainActor.run {
        task.recording.transcription?.status = .error(message: error.localizedDescription)
      }
    }
  }

  func cancelTask(id: TranscriptionTask.ID) {
    if id == currentTaskID {
      currentWhisperContext?.context.cancel()
    }
  }

  func cancelCurrentTask() {
    currentWhisperContext?.context.cancel()
  }

  private func resolveContextFor(useGPU: Bool, task: TranscriptionTaskEnvelope) async throws -> WhisperContextProtocol {
    if let currentContext = currentWhisperContext, await currentContext.modelType == task.modelType, currentContext.useGPU == useGPU {
      return currentContext.context
    } else {
      currentWhisperContext = nil
      let selectedModel = await FileManager.default.fileExists(atPath: task.modelType.localURL.path) ? task.modelType : .default
      // Update model type in case it of fallback to default
      await MainActor.run { task.task.settings.selectedModel = selectedModel }

      let memory = freeMemoryAmount()
      logs.info("Available memory: \(bytesToReadableString(bytes: availableMemory()))")
      logs.info("Free memory: \(bytesToReadableString(bytes: memory))")

      guard memory > selectedModel.memoryRequired else {
        throw LocalTranscriptionError.notEnoughMemory(available: memory, required: selectedModel.memoryRequired)
      }

      let context = try WhisperContext(modelPath: selectedModel.localURL.path, useGPU: useGPU)
      currentWhisperContext = (context, selectedModel, useGPU)
      return context
    }
  }
}
