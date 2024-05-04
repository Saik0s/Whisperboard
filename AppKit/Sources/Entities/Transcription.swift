import Foundation
import ComposableArchitecture

// MARK: - Transcription

struct Transcription: Codable, Hashable, Identifiable {
  let id: UUID
  var fileName: String
  var startDate: Date = .init()
  var segments: [Segment] = []
  var parameters: TranscriptionParameters
  var model: VoiceModelType
  var status: Status = .notStarted

  var text: String {
    segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

// MARK: Transcription.Status

extension Transcription {
  @CasePathable
  enum Status: Codable, Hashable {
    case notStarted
    case loading
    case uploading(Double)
    case error(message: String)
    case progress(Double)
    case done(Date)
    case canceled
    case paused(TranscriptionTask, progress: Double)
  }
}

// MARK: - Segment

struct Segment: Codable, Hashable, Identifiable {
  var id: Int64 { startTime }
  let startTime: Int64
  let endTime: Int64
  let text: String
  let tokens: [Token]
  let speaker: String?
}

// MARK: - Token

struct Token: Codable, Hashable, Identifiable {
  let id: Int32
  let index: Int32
  let text: String
  let data: TokenData
  let speaker: String?
}

// MARK: - TokenData

struct TokenData: Codable, Hashable, Identifiable {
  let id: Int
  let tid: Int
  let probability: Float
  let logProbability: Float
  let timestampProbability: Float
  let sumTimestampProbabilities: Float
  let startTime: Int64
  let endTime: Int64
  let voiceLength: Float
}

extension Transcription.Status {
  var isDone: Bool {
    switch self {
    case .done:
      true

    default:
      false
    }
  }

  var isNotStarted: Bool {
    switch self {
    case .notStarted:
      true

    default:
      false
    }
  }

  var isLoading: Bool {
    switch self {
    case .loading:
      true

    default:
      false
    }
  }

  var isUploading: Bool {
    switch self {
    case .uploading:
      true

    default:
      false
    }
  }

  var isCanceled: Bool {
    switch self {
    case .canceled:
      true

    default:
      false
    }
  }

  var isProgress: Bool {
    switch self {
    case .progress:
      true

    default:
      false
    }
  }

  var isError: Bool {
    switch self {
    case .error:
      true

    default:
      false
    }
  }

  var uploadProgress: Double? {
    switch self {
    case let .uploading(progress):
      progress

    default:
      nil
    }
  }

  var progressValue: Double? {
    switch self {
    case let .progress(progress):
      progress

    default:
      nil
    }
  }

  var errorMessage: String? {
    switch self {
    case let .error(message: message):
      message

    default:
      nil
    }
  }

  var isLoadingOrProgress: Bool {
    switch self {
    case .loading, .progress, .uploading:
      true

    default:
      false
    }
  }

  var isErrorOrCanceled: Bool {
    switch self {
    case .canceled, .error:
      true

    default:
      false
    }
  }

  var isPaused: Bool {
    switch self {
    case .paused:
      true

    default:
      false
    }
  }
}

#if DEBUG
  extension Transcription {
    static let mock1 = Transcription(
      id: UUID(),
      fileName: "test1",
      startDate: Date(),
      segments: [
        Segment(
          startTime: 0,
          endTime: 0,
          text: "This is a random sentence.",
          tokens: [
            Token(
              id: 0,
              index: 0,
              text: "This is a random sentence.",
              data: TokenData(
                id: 0,
                tid: 0,
                probability: 0,
                logProbability: 0,
                timestampProbability: 0,
                sumTimestampProbabilities: 0,
                startTime: 0,
                endTime: 0,
                voiceLength: 0
              ),
              speaker: nil
            ),
          ],
          speaker: nil
        ),
      ],
      parameters: TranscriptionParameters(),
      model: .tiny,
      status: .done(Date())
    )

    static let mock2 = Transcription(
      id: UUID(),
      fileName: "test2",
      startDate: Date(),
      segments: [
        Segment(
          startTime: 0,
          endTime: 0,
          text: "This is another random sentence. Here is a second sentence.",
          tokens: [
            Token(
              id: 0,
              index: 0,
              text: "This is another random sentence. Here is a second sentence.",
              data: TokenData(
                id: 0,
                tid: 0,
                probability: 0,
                logProbability: 0,
                timestampProbability: 0,
                sumTimestampProbabilities: 0,
                startTime: 0,
                endTime: 0,
                voiceLength: 0
              ),
              speaker: nil
            ),
          ],
          speaker: nil
        ),
      ],
      parameters: TranscriptionParameters(),
      model: .tiny,
      status: .done(Date())
    )

    static let mock3 = Transcription(
      id: UUID(),
      fileName: "test3",
      startDate: Date(),
      segments: [
        Segment(
          startTime: 0,
          endTime: 0,
          text: "Here is a random sentence. This is a second sentence. And a third one.",
          tokens: [
            Token(
              id: 0,
              index: 0,
              text: "Here is a random sentence. This is a second sentence. And a third one.",
              data: TokenData(
                id: 0,
                tid: 0,
                probability: 0,
                logProbability: 0,
                timestampProbability: 0,
                sumTimestampProbabilities: 0,
                startTime: 0,
                endTime: 0,
                voiceLength: 0
              ),
              speaker: nil
            ),
          ],
          speaker: nil
        ),
      ],
      parameters: TranscriptionParameters(),
      model: .tiny,
      status: .done(Date())
    )
  }
#endif
