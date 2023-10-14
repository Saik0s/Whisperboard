import Dependencies
import Foundation

// MARK: - RemoteTranscriptionError

enum RemoteTranscriptionError: Error {
  case uploadFailed
  case resultFailed
}

// MARK: - RemoteTranscriptionWorkExecutor

final class RemoteTranscriptionWorkExecutor: TranscriptionWorkExecutor {
  private let updateTranscription: (_ transcription: Transcription) -> Void

  @Dependency(\.apiClient) var apiClient: APIClient
  @Dependency(\.continuousClock) var clock

  private var processingTask: Task<Void, Never>?

  init(updateTranscription: @escaping (_ transcription: Transcription) -> Void) {
    self.updateTranscription = updateTranscription
  }

  func processTask(_ task: TranscriptionTask, updateTask: @escaping (TranscriptionTask) -> Void) async {
    processingTask = Task<Void, Never> {
      var task: TranscriptionTask = task {
        didSet { updateTask(task) }
      }
      var transcription = Transcription(id: task.id, fileName: task.fileName, parameters: task.parameters, model: task.modelType) {
        didSet { updateTranscription(transcription) }
      }

      do {
        transcription.status = .loading

        let fileURL = task.fileURL

        let uploadResponse = try await apiClient.uploadRecordingAt(fileURL)
        log.debug("Uploaded:", uploadResponse)
        task.remoteID = uploadResponse.id
        transcription.status = .progress(0.0)

        for try await _ in clock.timer(interval: .seconds(3)) {
          log.debug("Checking transcription status")
          let resultResponse = try await apiClient.getTranscriptionResultFor(uploadResponse.id)
          log.debug("Result:", resultResponse)
          guard resultResponse.isDone else {
            log.debug("Transcription is not done yet")
            continue
          }

          log.debug(resultResponse.transcription as Any)
          transcription.segments = resultResponse.transcription?.segments.enumerated().map { offset, segment in
            Segment(
              index: offset,
              startTime: Int64(segment.start * 1000),
              endTime: Int64(segment.end * 1000),
              text: segment.text,
              tokens: [],
              speaker: nil
            )
          } ?? []
          transcription.status = .done(Date())
          return
        }
      } catch {
        log.error(error)
        transcription.status = .error(message: error.localizedDescription)
      }
    }

    await processingTask?.value
    processingTask = nil
  }

  func cancel(task _: TranscriptionTask) {
    processingTask?.cancel()
  }
}
