import Foundation

// MARK: - TranscriptionWorkExecutor

protocol TranscriptionWorkExecutor {
  func process(task: TranscriptionTaskEnvelope) async
  func cancelTask(id: TranscriptionTaskEnvelope.ID)
}
