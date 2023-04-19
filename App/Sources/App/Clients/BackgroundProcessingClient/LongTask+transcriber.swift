import AppDevUtils
import Dependencies
import Foundation

// MARK: - LongTaskTranscriptError

enum LongTaskTranscriptError: Error {
  case noRecordingInfo
  case failedToTranscribe
}

extension LongTask {
  static var transcription: LongTask<RecordingInfo.ID> {
    LongTask<RecordingInfo.ID>(identifier: "me.igortarasenko.Whisperboard") { id in
      @Dependency(\.transcriber) var transcriber: TranscriberClient
      @Dependency(\.storage) var storage: StorageClient
      @Dependency(\.settings) var settings: SettingsClient

      guard let recordingInfo = storage.read()[id: id] else {
        throw LongTaskTranscriptError.noRecordingInfo
      }

      let fileURL = storage.audioFileURLWithName(recordingInfo.fileName)
      let language = settings.settings().voiceLanguage
      let text = try await transcriber.transcribeAudio(fileURL, language)
      try storage.update(recordingInfo.id) {
        $0.text = text
        $0.isTranscribed = true
      }
    }
  }
}
