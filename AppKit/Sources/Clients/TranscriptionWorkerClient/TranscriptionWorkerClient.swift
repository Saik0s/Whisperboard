
import AsyncAlgorithms
import BackgroundTasks
import Combine
import ComposableArchitecture
import Dependencies
import IdentifiedCollections
import UIKit

// MARK: - TranscriptionWorkerClient

struct TranscriptionWorkerClient {
  var enqueueTask: @Sendable (TranscriptionTask) async -> Void
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
    let workExecutor = LocalTranscriptionWorkExecutor { transcription in
      Task { @MainActor in
        await transcriptionChannel.send(transcription)
      }
    }

    let worker: TranscriptionWorker = TranscriptionWorkerImpl(executor: workExecutor)

    return TranscriptionWorkerClient(
      enqueueTask: { task in
        worker.enqueueTask(task)
      },
      cancelTaskForFile: { fileName in
        if let task = worker.getAllTasks().first(where: { $0.fileName == fileName }) {
          if worker.currentTaskID == task.id {
            workExecutor.currentWhisperContext?.context.cancel()
          }
          worker.removeTask(with: task.id)
        }
      },
      cancelAllTasks: {
        workExecutor.currentWhisperContext?.context.cancel()
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
      enqueueTask: { task in
        Task {
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
