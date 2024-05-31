import Dependencies
import Foundation

// MARK: - TranscriptionWorkExecutor

protocol TranscriptionWorkExecutor {
  var currentTaskID: TranscriptionTask.ID? { get }
  func process(task: TranscriptionTaskEnvelope) async
  func cancelTask(id: TranscriptionTask.ID)
}

extension DependencyValues {
  var localTranscriptionWorkExecutor: TranscriptionWorkExecutor {
    get { self[TranscriptionWorkExecutorKey.self] }
    set { self[TranscriptionWorkExecutorKey.self] = newValue }
  }
}

// MARK: - TranscriptionWorkExecutorKey

private enum TranscriptionWorkExecutorKey: DependencyKey {
  static let liveValue: TranscriptionWorkExecutor = LocalTranscriptionWorkExecutor()
}
