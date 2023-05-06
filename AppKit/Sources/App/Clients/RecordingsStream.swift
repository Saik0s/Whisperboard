import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Foundation

extension DependencyValues {
  var recordingsStream: AsyncStream<[RecordingEnvelop]> {
    get { self[RecordingsStreamKey.self] }
    set { self[RecordingsStreamKey.self] = newValue }
  }

  private enum RecordingsStreamKey: DependencyKey {
    typealias Value = AsyncStream<[RecordingEnvelop]>

    static let liveValue: Value = {
      @Dependency(\.transcriber) var transcriber: TranscriberClient
      @Dependency(\.storage) var storage: StorageClient

      // Initially it was implemented using CombineLatest from Combine framework,
      // but there was a problem with data races and CombineLatest skipping events.
      return AsyncCombineLatest2Sequence(storage.recordingsInfoStream, transcriber.transcriptionStateStream)
        .map { (info: [RecordingInfo], state: [FileName: TranscriptionState]) in
          info.map { (currentInfo: RecordingInfo) in
            RecordingEnvelop(currentInfo, state[currentInfo.fileName])
          }
        }
        .eraseToStream()
    }()

    static let testValue: Value = liveValue

    static let previewValue: Value = liveValue
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
