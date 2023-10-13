import Foundation

// MARK: - TranscriptionWorkExecutor

protocol TranscriptionWorkExecutor {
  func processTask(_ task: TranscriptionTask, updateTask: @escaping (TranscriptionTask) -> Void) async
  func cancel(task: TranscriptionTask)
}
