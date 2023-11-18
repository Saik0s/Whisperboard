
import AsyncAlgorithms
import BackgroundTasks
import Combine
import ComposableArchitecture
import Dependencies
import IdentifiedCollections
import UIKit

// MARK: - TranscriptionWorkerClient

struct TranscriptionWorkerClient {
  var enqueueTaskForRecording: @Sendable (RecordingInfo, Settings) -> Void
  var cancelTaskForFile: @Sendable (_ fileName: String) async -> Void
  var cancelAllTasks: @Sendable () async -> Void
  var registerForProcessingTask: @Sendable () -> Void
  var transcriptionStream: @Sendable () -> AsyncStream<Transcription>
  var getAvailableLanguages: @Sendable () -> [VoiceLanguage]
  var tasksStream: @Sendable () -> AsyncStream<IdentifiedArrayOf<TranscriptionTask>>
  var getTasks: @Sendable () -> IdentifiedArrayOf<TranscriptionTask>
}

// MARK: DependencyKey

extension TranscriptionWorkerClient: DependencyKey {
  static let liveValue: TranscriptionWorkerClient = {
    let transcriptionChannel = AsyncChannel<Transcription>()
    let updateTranscription: (_ transcription: Transcription) -> Void = { transcription in
      Task { @MainActor in
        await transcriptionChannel.send(transcription)
      }
    }
    let combinedWorkExecutor = CombinedTranscriptionWorkExecutor(updateTranscription: updateTranscription)

    let worker: TranscriptionWorker = TranscriptionWorkerImpl(executor: combinedWorkExecutor)

    return TranscriptionWorkerClient(
      enqueueTaskForRecording: { recording, settings in
        let task = TranscriptionTask(
          fileName: recording.fileName,
          duration: Int64(recording.duration * 1000),
          parameters: settings.parameters,
          modelType: settings.selectedModel,
          isRemote: settings.isRemoteTranscriptionEnabled
        )
        worker.enqueueTask(task)
      },
      cancelTaskForFile: { fileName in
        if let task = worker.getAllTasks().first(where: { $0.fileName == fileName }) {
          if worker.currentTaskID == task.id {
            combinedWorkExecutor.cancel(task: task)
          }
          worker.removeTask(with: task.id)
        }
      },
      cancelAllTasks: {
        worker.getAllTasks().forEach(combinedWorkExecutor.cancel(task:))
        worker.removeAllTasks()
      },
      registerForProcessingTask: {
        worker.registerForProcessingTask()
      },
      transcriptionStream: {
        defer {
          Task.detached { await worker.processTasks() }
        }
        return transcriptionChannel.eraseToStream()
      },
      getAvailableLanguages: {
        [.auto] + WhisperContext.getAvailableLanguages()
      },
      tasksStream: {
        worker.tasksStream()
      },
      getTasks: {
        worker.getAllTasks()
      }
    )
  }()
}

extension DependencyValues {
  var transcriptionWorker: TranscriptionWorkerClient {
    get { self[TranscriptionWorkerClient.self] }
    set { self[TranscriptionWorkerClient.self] = newValue }
  }
}

extension TranscriptionWorkerClient {
  static let testValue: TranscriptionWorkerClient = {
    let transcriptionChannel = AsyncChannel<Transcription>()
    let tasksChannel = AsyncChannel<IdentifiedArrayOf<TranscriptionTask>>()

    return TranscriptionWorkerClient(
      enqueueTaskForRecording: { recording, settings in
        Task {
          let task = TranscriptionTask(
            fileName: recording.fileName,
            duration: Int64(recording.duration * 1000),
            parameters: settings.parameters,
            modelType: settings.selectedModel,
            isRemote: settings.isRemoteTranscriptionEnabled
          )
          await tasksChannel.send([task])
          await transcriptionChannel.send(Transcription(
            id: task.id,
            fileName: task.fileName,
            startDate: Date(),
            segments: [],
            parameters: task.parameters,
            model: task.modelType,
            status: .progress(0.1)
          ))
        }
      },
      cancelTaskForFile: { _ in },
      cancelAllTasks: {},
      registerForProcessingTask: {},
      transcriptionStream: { transcriptionChannel.eraseToStream() },
      getAvailableLanguages: {
        [.auto] + WhisperContext.getAvailableLanguages()
      },
      tasksStream: { tasksChannel.eraseToStream() },
      getTasks: { [] }
    )
  }()
}
