import ComposableArchitecture
import Foundation

// MARK: - TranscriptionTaskEnvelope

@MainActor
public struct TranscriptionTaskEnvelope {
  public var id: TranscriptionTask.ID { task.id }
  @Shared public var task: TranscriptionTask
  @Shared public var recording: RecordingInfo

  public var isPaused: Bool { recording.transcription?.status.isPaused == true }

  public var segments: [Segment] { recording.transcription?.segments ?? [] }
  public var duration: TimeInterval { recording.duration }
  public var offset: TimeInterval { recording.offsetSeconds }
  public var progress: Double { recording.transcription?.progress ?? 0 }

  public var fileName: String { recording.fileName }
  public var modelType: String { task.settings.selectedModelName }
  public var parameters: TranscriptionParameters { task.settings.parameters }

  public init(task: Shared<TranscriptionTask>, recording: Shared<RecordingInfo>) {
    _task = task
    _recording = recording
  }
}
