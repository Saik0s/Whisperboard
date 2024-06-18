import AsyncAlgorithms
import AudioProcessing
import Common
import Dependencies
import Foundation
import WhisperKit

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
  @Dependency(RecordingTranscriptionStream.self) var transcriptionStream

  init() {}

  func process(task: TranscriptionTaskEnvelope) async {
    let taskId = await MainActor.run { task.id }
    logs.debug("Starting transcription process for task ID: \(taskId)")
    currentTaskID = taskId
    defer {
      logs.debug("Ending transcription process for task ID: \(taskId)")
      currentTaskID = nil
    }

    DispatchQueue.main.async {
      if task.recording.transcription?.id != taskId {
        logs.debug("Initializing new transcription for task ID: \(taskId)")
        task.recording.transcription = Transcription(id: taskId, fileName: task.fileName, parameters: task.parameters, model: task.modelType)
      }
    }

    do {
      DispatchQueue.main.async {
        logs.debug("Setting transcription status to loading for task ID: \(taskId)")
        task.recording.transcription?.status = .loading
      }

      try await transcriptionStream.loadModel(task.modelType) { progress in
        logs.debug("Model load progress for task ID \(taskId): \(progress * 100)%")
      }

      DispatchQueue.main.async {
        logs.debug("Setting transcription status to progress for task ID: \(taskId)")
        task.recording.transcription?.status = .progress(task.progress, text: "")
      }

      let fileURL = await task.recording.fileURL
      logs.debug("File URL for task ID \(taskId): \(fileURL)")

      // // TODO: add support for resuming
      // var parameters = await task.parameters
      // parameters.offsetMilliseconds = await Int(task.offset)
      //       self.confirmedSegments = segments.map { segment in
      //     var adjustedSegment = segment
      //     adjustedSegment.start += initialSkipDuration
      //     adjustedSegment.end += initialSkipDuration
      //     return adjustedSegment
      // }

      for try await transcriptionState in await transcriptionStream.startBufferTranscription()._throttle(for: .seconds(0.1)) {
        DispatchQueue.main.async {
          let simpleSegments = transcriptionState.segments.map(\.asSimpleSegment)
          let progress = transcriptionState.transcriptionProgressFraction
          task.recording.transcription?.segments = simpleSegments
          task.recording.transcription?.status = .progress(progress, text: transcriptionState.currentText)
//          var mainTexts = simpleSegments.map(\.text)
//          mainTexts.append(transcriptionState.currentText)
//          let mainText = mainTexts.reduce("") { result, text in
//            if result.hasSuffix(".") || result.hasSuffix("!") || result.hasSuffix("?") {
//              result + "\n" + text
//            } else {
//              result + " " + text
//            }
//          }
          task.recording.transcription?.text = transcriptionState.currentText // mainText.trimmingCharacters(in: .whitespacesAndNewlines)
          task.recording.transcription?.words = transcriptionState.confirmedWords.map { (word: WordTiming) in
            WordData(
              word: word.word,
              startTime: Double(word.start),
              endTime: Double(word.end),
              probability: Double(word.probability)
            )
          }

          logs
            .debug(
              "Transcription update for task ID \(taskId): segments \(simpleSegments.count), progress \(task.progress), duration \(task.recording.duration * progress)"
            )
        }
      }
      DispatchQueue.main.async {
        logs.debug("Setting transcription status to done for task ID: \(taskId)")
        task.recording.transcription?.status = .done(Date())
      }
    } catch {
      DispatchQueue.main.async {
        logs.error("Error during transcription for task ID \(taskId): \(error.localizedDescription)")
        task.recording.transcription?.status = .error(message: error.localizedDescription)
      }
    }
  }
}
