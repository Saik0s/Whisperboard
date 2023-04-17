import Foundation
import Dependencies
import AppDevUtils

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

      guard let recordingInfo = try await storage.read()[id: id] else {
        throw LongTaskTranscriptError.noRecordingInfo
      }

      let fileURL = storage.audioFileURLWithName(recordingInfo.fileName)
      let language = settings.settings().voiceLanguage
      for await progress in transcriber.transcribeAudio(fileURL, language) {
        switch progress {
        case .loadingModel:
          log.verbose("Loading model...")
        case .started:
          log.verbose("Transcribing...")
        case let .newSegment(segment):
          log.verbose("New segment: \(segment)")
        case let .finished(finalText):
          log.verbose("Finished: \(finalText)")
        case let .error(error):
          log.verbose("Error: \(error)")
          throw LongTaskTranscriptError.failedToTranscribe
        }
      }
    }
  }
}
