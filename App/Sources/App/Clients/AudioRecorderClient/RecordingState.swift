import AppDevUtils
import Foundation

public enum RecordingState: Equatable {
  case recording(duration: TimeInterval, power: Float)
  case paused
  case stopped
  case finished(Bool)
  case error(EquatableErrorWrapper)
}
