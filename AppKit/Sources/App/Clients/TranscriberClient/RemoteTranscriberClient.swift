import AppDevUtils
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import os.log
import RecognitionKit
import SwiftUI

// MARK: - RemoteTranscriberClient

struct RemoteTranscriberClient {
  var transcribeAudio: @Sendable (_ audioURL: URL, _ language: VoiceLanguage) async throws -> String
}

extension RemoteTranscriberClient {
  struct Word: Codable {
    let word: String
    let start: Double
    let end: Double
    let score: Double
    let speaker: String?
  }

  struct TranscriptionSegment: Codable {
    let start: Double
    let end: Double
    let text: String
    let words: [Word]?
    let speaker: String?
  }

  enum Response {
    struct Start: Codable {
      let id: String
    }

    struct Finish: Codable {
      let segments: [TranscriptionSegment]
      let language: String?
    }
  }
}

// MARK: DependencyKey

extension RemoteTranscriberClient: DependencyKey {
  static let liveValue: Self = {
    @Dependency(\.transcriptionsStream) var transcriptionsStream: TranscriptionsStream

    return RemoteTranscriberClient(
      transcribeAudio: { audioURL, _ in
        let fileName = audioURL.lastPathComponent
        log.verbose("Remotely transcribing \(fileName)...")

        do {
          transcriptionsStream.updateStateKey(fileName: fileName, keyPath: \.progress, value: .loadingModel)
          let callId = try await sendFile(fileUrl: audioURL)
          transcriptionsStream.updateStateKey(fileName: fileName, keyPath: \.progress, value: .transcribing([]))
          let result: Response.Finish = try await waitForResults(callId: callId)
          let text = result.segments.map(\.text).joined(separator: " ")
          transcriptionsStream.updateStateKey(fileName: fileName, keyPath: \.finalText, value: text)
          // transcriptionsStream.updateState(fileName: fileName, state: nil)
          return text
        } catch {
          transcriptionsStream.updateStateKey(fileName: fileName, keyPath: \.error, value: error as? TranscriberError ?? .cancelled)
          log.error(error)
          throw error
        }
      }
    )
  }()
}

extension DependencyValues {
  var remoteTranscriber: RemoteTranscriberClient {
    get { self[RemoteTranscriberClient.self] }
    set { self[RemoteTranscriberClient.self] = newValue }
  }
}
