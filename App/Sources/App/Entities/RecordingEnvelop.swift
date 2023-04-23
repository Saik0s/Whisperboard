import Foundation

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
