//
// Created by Igor Tarasenko on 13/10/2023.
//

import Foundation

final class CombinedTranscriptionWorkExecutor: TranscriptionWorkExecutor {
  private let updateTranscription: (_ transcription: Transcription) -> Void
  private lazy var localWorkExecutor = LocalTranscriptionWorkExecutor(updateTranscription: updateTranscription)
  private lazy var remoteWorkExecutor = RemoteTranscriptionWorkExecutor(updateTranscription: updateTranscription)

  init(updateTranscription: @escaping (_ transcription: Transcription) -> Void) {
    self.updateTranscription = updateTranscription
  }

  func processTask(_ task: TranscriptionTask, updateTask: @escaping (TranscriptionTask) -> Void) async {
    if task.isRemote {
      await remoteWorkExecutor.processTask(task, updateTask: updateTask)
    } else {
      await localWorkExecutor.processTask(task, updateTask: updateTask)
    }
  }

  func cancel(task: TranscriptionTask) {
    if task.isRemote {
      remoteWorkExecutor.cancel(task: task)
    } else {
      localWorkExecutor.cancel(task: task)
    }
  }
}
