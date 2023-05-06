import AppDevUtils
import Dependencies
import Foundation

// MARK: - LongTaskTranscriptError

enum LongTaskTranscriptError: Error {
  case noRecordingInfo
  case failedToTranscribe
}

extension LongTask {
  /// Creates and returns a long task that transcribes an audio recording and updates the storage.
  ///
  /// - parameter id: The identifier of the recording to be transcribed.
  /// - throws: A `LongTaskTranscriptError` if the recording info is not found or the transcription fails.
  /// - note: The task uses the dependencies injected by the `@Dependency` property wrapper.
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
      let isParallel = settings.settings().isParallelEnabled
      let text = try await transcriber.transcribeAudio(fileURL, language, isParallel)
      try storage.update(recordingInfo.id) {
        $0.text = text
        $0.isTranscribed = true
      }
    }
  }
}
