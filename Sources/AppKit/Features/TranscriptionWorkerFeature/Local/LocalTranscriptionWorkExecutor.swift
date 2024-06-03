import Common
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
  var currentTaskID: TranscriptionTask.ID?
  @Dependency(ModelManagement.self) var modelManagement
  @Dependency(RecordingTranscriptionStream.self) var transcriptionStream

  init() {}

  fileprivate func whisperKitProcess(_: TranscriptionTaskEnvelope) async throws {
    // for try await action in context.fullTranscribe(audioFileURL: fileURL, params: parameters) {
    //   logs.debug("Received WhisperAction: \(action)")
    //   switch action {
    //   case let .newSegment(segment):
    //     if await segment.startTime >= (task.recording.transcription?.segments.last?.endTime ?? 0) {
    //       logs.debug("Segment start time is not after the last segment end time")
    //     }
    //     await MainActor.run {
    //       task.recording.transcription?.segments.append(segment)
    //       task.recording.transcription?.status = .progress(task.progress)
    //     }

    //   case let .progress(progress):
    //     logs.debug("Progress: \(progress)")

    //   case let .error(error):
    //     await MainActor.run {
    //       task.recording.transcription?.status = .error(message: error.localizedDescription)
    //     }

    //   case .canceled:
    //     await MainActor.run {
    //       task.recording.transcription?.status = .canceled
    //     }

    //   case .finished:
    //     await MainActor.run {
    //       task.recording.transcription?.status = .done(Date())
    //     }
    //   }
    // }
  }

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

      for try await modelState in try await modelManagement.loadModel(task.modelType.fileName) {
        logs.debug("Model state: \(modelState)")
      }

      await MainActor.run {
        task.recording.transcription?.status = .progress(task.progress)
      }

      let fileURL = await task.recording.fileURL

      // // TODO: add support for resuming
      // var parameters = await task.parameters
      // parameters.offsetMilliseconds = await Int(task.offset)

      // loop through transcription updates

      for try await transcriptionState in await transcriptionStream.startFileTranscription(fileURL: fileURL) {
        await MainActor.run {
          task.recording.transcription?.segments = transcriptionState.segments.map(\.asSimpleSegment)
          task.recording.transcription?.status = .progress(task.progress)
        }
      }
      await MainActor.run {
        task.recording.transcription?.status = .done(Date())
      }
    } catch {
      await MainActor.run {
        // Check if it was just canceled
        task.recording.transcription?.status = .error(message: error.localizedDescription)
      }
    }
  }
}
