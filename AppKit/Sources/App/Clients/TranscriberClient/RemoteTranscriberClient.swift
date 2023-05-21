import AppDevUtils
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import os.log
import RecognitionKit
import SwiftUI

struct RemoteTranscriberClient {
  var startAudioTranscription: @Sendable (_ audioURL: URL, _ language: VoiceLanguage) async throws -> Response.Start
  var checkAudioTranscription: @Sendable (_ id: String) async throws -> Response.Status
}

extension RemoteTranscriberClient {
  struct Word: Codable {
    let word: String
    let start: Double
    let end: Double
    let score: Double
    let speaker: String
  }

  struct TranscriptionSegment: Codable {
    let start: Double
    let end: Double
    let text: String
    let words: [Word]
    let speaker: String
  }

  typealias Transcription = [TranscriptionSegment]

  enum Response {
    struct Start: Codable {
      let id: String
    }

    struct Status: Codable {
      let id: String
      let status: String
      let text: String
      let transcription: Transcription
    }
  }
}

extension RemoteTranscriberClient: DependencyKey {
  static let liveValue: Self = {
    RemoteTranscriberClient(
      startAudioTranscription: { _, _ in Response.Start(id: "1") },
      checkAudioTranscription: { id in
        Response.Status(id: "id, status: "", text: "", transcription: [])
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
