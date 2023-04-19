import Combine
import Dependencies
import Foundation

// MARK: - RecordingEnvelop

@dynamicMemberLookup
public struct RecordingEnvelop: Hashable {
  let recordingInfo: RecordingInfo
  let transcriptionState: TranscriptionState?

  public init(_ recordingInfo: RecordingInfo, _ transcriptionState: TranscriptionState?) {
    self.recordingInfo = recordingInfo
    self.transcriptionState = transcriptionState
  }

  public subscript<Subject>(dynamicMember keyPath: KeyPath<RecordingInfo, Subject>) -> Subject {
    recordingInfo[keyPath: keyPath]
  }

  public subscript<Subject>(dynamicMember keyPath: KeyPath<TranscriptionState?, Subject>) -> Subject {
    transcriptionState[keyPath: keyPath]
  }
}

extension DependencyValues {
  var recordingsStream: @Sendable () -> AnyPublisher<[RecordingEnvelop], Never> {
    get { self[RecordingsStreamKey.self] }
    set { self[RecordingsStreamKey.self] = newValue }
  }

  private enum RecordingsStreamKey: DependencyKey {
    typealias Value = @Sendable () -> AnyPublisher<[RecordingEnvelop], Never>

    static let liveValue: @Sendable () -> AnyPublisher<[RecordingEnvelop], Never> = {
      @Dependency(\.transcriber) var transcriber: TranscriberClient
      @Dependency(\.storage) var storage: StorageClient

      let transcriptions = transcriber.transcriptionStateStream()

      return storage
        .recordingsInfoStream()
        .combineLatest(transcriptions) { (info: [RecordingInfo], state: [FileName: TranscriptionState]) in
          info.map { (currentInfo: RecordingInfo) in
            RecordingEnvelop(currentInfo, state[currentInfo.fileName])
          }
        }
        .receive(on: RunLoop.main)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
  }
}

#if DEBUG
  extension RecordingEnvelop {
    static var fixtures: [RecordingEnvelop] {
      RecordingInfo.fixtures.map { RecordingEnvelop($0, nil) }
    }

    static var mock: RecordingEnvelop {
      RecordingEnvelop(.mock, nil)
    }
  }
#endif
