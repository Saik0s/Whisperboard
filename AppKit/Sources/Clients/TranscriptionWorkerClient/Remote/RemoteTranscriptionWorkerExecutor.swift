import Dependencies
import Foundation

// MARK: - RemoteTranscriptionError

enum RemoteTranscriptionError: Error, LocalizedError {
  case uploadFailed
  case resultFailed

  var errorDescription: String? {
    switch self {
    case .uploadFailed:
      return "Failed to upload recording"
    case .resultFailed:
      return "Failed to get transcription result"
    }
  }
}

// MARK: - RemoteTranscriptionWorkExecutor

final class RemoteTranscriptionWorkExecutor: TranscriptionWorkExecutor {
  private let updateTranscription: (_ transcription: Transcription) -> Void

  @Dependency(\.apiClient) var apiClient: APIClient
  @Dependency(\.continuousClock) var clock
  @Dependency(\.storage) var storage

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
        transcription.status = .uploading(0.0)

        let fileURL = storage.audioFileURLWithName(task.fileName)
        task.remoteID = nil

        for try await uploadProgress in apiClient.uploadRecordingAt(fileURL) {
          switch uploadProgress {
          case let .uploading(progress):
            transcription.status = .uploading(progress)
          case let .done(response):
            log.debug("Uploaded:", response)
            task.remoteID = response.id
            transcription.status = .progress(0.0)
          }
        }

        guard let remoteID = task.remoteID else {
          log.error("Failed to upload recording")
          transcription.status = .error(message: "Failed to upload recording")
          return
        }

        for try await _ in clock.timer(interval: .seconds(1)) {
          log.debug("Checking transcription status")
          let resultResponse = try await apiClient.getTranscriptionResultFor(remoteID)
          log.debug("Result:", resultResponse)
          guard resultResponse.isDone else {
            log.debug("Transcription is not done yet")
            continue
          }

          log.debug(resultResponse.transcription as Any)
          transcription.segments = resultResponse.transcription?.segments.map { segment in
            Segment(
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
