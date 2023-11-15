import Foundation

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
  enum Status: Codable, Hashable {
    case notStarted, loading, uploading(Double), error(message: String), progress(Double), done(Date), canceled
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
      return true
    default:
      return false
    }
  }

  var isNotStarted: Bool {
    switch self {
    case .notStarted:
      return true
    default:
      return false
    }
  }

  var isLoading: Bool {
    switch self {
    case .loading:
      return true
    default:
      return false
    }
  }

  var isUploading: Bool {
    switch self {
    case .uploading:
      return true
    default:
      return false
    }
  }

  var isCanceled: Bool {
    switch self {
    case .canceled:
      return true
    default:
      return false
    }
  }

  var isProgress: Bool {
    switch self {
    case .progress:
      return true
    default:
      return false
    }
  }

  var isError: Bool {
    switch self {
    case .error:
      return true
    default:
      return false
    }
  }

  var uploadProgress: Double? {
    switch self {
    case let .uploading(progress):
      return progress
    default:
      return nil
    }
  }

  var progressValue: Double? {
    switch self {
    case let .progress(progress):
      return progress
    default:
      return nil
    }
  }

  var errorMessage: String? {
    switch self {
    case let .error(message: message):
      return message
    default:
      return nil
    }
  }

  var isLoadingOrProgress: Bool {
    switch self {
    case .loading, .progress, .uploading:
      return true
    default:
      return false
    }
  }

  var isErrorOrCanceled: Bool {
    switch self {
    case .canceled, .error:
      return true
    default:
      return false
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
