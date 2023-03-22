import Foundation

extension TranscriberClient {
  func transcribeAudio(url: URL, language: VoiceLanguage) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      Task.detached {
        var segments: [TranscriptionSegment] = []
        var text = ""

        for await progress in transcribeAudio(url, language) {
          switch progress {
          case .loadingModel:
            text = "Loading model..."
          case .started:
            text = "Transcribing..."
          case let .newSegment(segment):
            segments.append(segment)
            text = segments.joined(separator: " ")
          case let .finished(finalText):
            text = finalText
          case let .error(error):
            continuation.finish(throwing: error)
            return
          }

          continuation.yield(text)
        }

        continuation.finish()
      }
    }
  }
}
