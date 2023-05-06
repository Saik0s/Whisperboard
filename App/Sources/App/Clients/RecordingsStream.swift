import Combine
import Dependencies
import Foundation

extension DependencyValues {
  var recordingsStream: AnyPublisher<[RecordingEnvelop], Never> {
    get { self[RecordingsStreamKey.self] }
    set { self[RecordingsStreamKey.self] = newValue }
  }

  private enum RecordingsStreamKey: DependencyKey {
    typealias Value = AnyPublisher<[RecordingEnvelop], Never>

    static let liveValue: AnyPublisher<[RecordingEnvelop], Never> = {
      @Dependency(\.transcriber) var transcriber: TranscriberClient
      @Dependency(\.storage) var storage: StorageClient

      return Publishers.CombineLatest(
        storage.recordingsInfoStream,
        transcriber.transcriptionStateStream
      ).map { (info: [RecordingInfo], state: [FileName: TranscriptionState]) in
        info.map { (currentInfo: RecordingInfo) in
          RecordingEnvelop(currentInfo, state[currentInfo.fileName])
        }
      }.print().eraseToAnyPublisher()
    }()
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
