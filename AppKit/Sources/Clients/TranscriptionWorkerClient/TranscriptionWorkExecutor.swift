import Foundation
import Dependencies

// MARK: - TranscriptionWorkExecutor

protocol TranscriptionWorkExecutor {
  func process(task: TranscriptionTaskEnvelope) async
  func cancelTask(id: TranscriptionTaskEnvelope.ID)
}

extension DependencyValues {
  var localTranscriptionWorkExecutor: TranscriptionWorkExecutor {
    get { self[TranscriptionWorkExecutorKey.self] }
    set { self[TranscriptionWorkExecutorKey.self] = newValue }
  }
}

// MARK: - DidBecomeActiveKey

private enum TranscriptionWorkExecutorKey: DependencyKey {
  static let liveValue: TranscriptionWorkExecutor = {
    LocalTranscriptionWorkExecutor()
  }()
}
