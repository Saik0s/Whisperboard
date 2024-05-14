import Foundation

public enum RecordingState: Equatable {
  case recording(duration: TimeInterval, powers: [Float])
  case paused
  case stopped
  case finished(Bool)
  case error(EquatableError)
}
