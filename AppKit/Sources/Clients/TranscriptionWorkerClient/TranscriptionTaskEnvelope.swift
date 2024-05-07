import ComposableArchitecture
import Foundation

// MARK: - TranscriptionTaskEnvelope

struct TranscriptionTaskEnvelope: Identifiable {
  var id: TranscriptionTask.ID { task.id }
  @Shared var task: TranscriptionTask
  @Shared var recording: RecordingInfo

  var isPaused: Bool { recording.transcription?.status.isPaused == true }

  var segments: [Segment] { recording.segments }
  var duration: Int64 { Int64(recording.duration) }
  var offset: Int64 { recording.offset }
  var progress: Double { recording.progress }

  var fileName: String { recording.fileName }
  var modelType: VoiceModelType { task.settings.selectedModel }
  var isRemote: Bool { task.settings.isRemoteTranscriptionEnabled }
  var parameters: TranscriptionParameters { task.settings.parameters }
}
