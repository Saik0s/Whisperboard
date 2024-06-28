import ComposableArchitecture
import Foundation

// MARK: - Transcription

public struct Transcription: Codable, Hashable, Identifiable {
  public let id: UUID
  public var fileName: String
  public var startDate: Date = .init()
  public var segments: [Segment] = []
  public var parameters: TranscriptionParameters
  public var model: String
  public var status: Status = .notStarted
  public var words: [WordData]
  public var text: String
  public var timings: Timings

  public var progress: Double {
    if case let .progress(progress, _) = status {
      return progress
    } else if case let .paused(_, progress: progress) = status {
      return progress
    } else if case .done = status {
      return 1
    }

    return 0
  }

  public init(
    id: UUID = UUID(),
    fileName: String,
    startDate: Date = .init(),
    segments: [Segment] = [],
    parameters: TranscriptionParameters,
    model: String,
    status: Status = .notStarted,
    words: [WordData] = [],
    text: String = "",
    timings: Timings = .init()
  ) {
    self.id = id
    self.fileName = fileName
    self.startDate = startDate
    self.segments = segments
    self.parameters = parameters
    self.model = model
    self.status = status
    self.words = words
    self.text = text
    self.timings = timings
  }
}

// MARK: Transcription.Timings

public extension Transcription {
  struct Timings: Codable, Hashable {
    public var tokensPerSecond: Double = 0
    public var fullPipeline: TimeInterval = 0

    public init(tokensPerSecond: Double = 0, fullPipeline: TimeInterval = 0) {
      self.tokensPerSecond = tokensPerSecond
      self.fullPipeline = fullPipeline
    }
  }
}

// MARK: Transcription.Status

public extension Transcription {
  @CasePathable
  enum Status: Codable, Hashable {
    case notStarted
    case loading
    case uploading(Double)
    case error(message: String)
    case progress(Double, text: String)
    case done(Date)
    case canceled
    case paused(TranscriptionTask, progress: Double)
  }
}

// MARK: - Segment

public struct Segment: Codable, Hashable, Identifiable {
  public var id: Int64 { startTime }
  public let startTime: Int64
  public let endTime: Int64
  public let text: String
  public let tokens: [Token]
  public let speaker: String?

  public init(
    startTime: Int64,
    endTime: Int64,
    text: String,
    tokens: [Token],
    speaker: String? = nil
  ) {
    self.startTime = startTime
    self.endTime = endTime
    self.text = text
    self.tokens = tokens
    self.speaker = speaker
  }
}

// MARK: - Token

public struct Token: Codable, Hashable, Identifiable {
  public let id: Int
  public let index: Int
  public let logProbability: Float
  public let speaker: String?

  public init(
    id: Int,
    index: Int,
    logProbability: Float,
    speaker: String? = nil
  ) {
    self.id = id
    self.index = index
    self.logProbability = logProbability
    self.speaker = speaker
  }
}

// MARK: - WordData

public struct WordData: Codable, Hashable {
  public let word: String
  public let startTime: TimeInterval
  public let endTime: TimeInterval
  public let probability: Double

  public init(
    word: String,
    startTime: TimeInterval,
    endTime: TimeInterval,
    probability: Double
  ) {
    self.word = word
    self.startTime = startTime
    self.endTime = endTime
    self.probability = probability
  }
}

public extension Transcription.Status {
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
    case let .progress(progress, _):
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
  public extension Transcription {
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
              logProbability: 0.1,
              speaker: nil
            ),
          ],
          speaker: nil
        ),
      ],
      parameters: TranscriptionParameters(),
      model: "tiny",
      status: .done(Date()),
      timings: Timings(tokensPerSecond: 1, fullPipeline: 1)
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
              logProbability: 0.1,
              speaker: nil
            ),
          ],
          speaker: nil
        ),
      ],
      parameters: TranscriptionParameters(),
      model: "tiny",
      status: .done(Date()),
      timings: Timings(tokensPerSecond: 1, fullPipeline: 1)
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
              logProbability: 0.1,
              speaker: nil
            ),
          ],
          speaker: nil
        ),
      ],
      parameters: TranscriptionParameters(),
      model: "tiny",
      status: .done(Date()),
      timings: Timings(tokensPerSecond: 1, fullPipeline: 1)
    )
  }
#endif
