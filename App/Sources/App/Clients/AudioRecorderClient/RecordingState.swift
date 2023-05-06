import AppDevUtils
import Foundation

/// An enumeration that represents the possible states of a recording session.
///
/// - recording: The recording is in progress, with the duration and power as associated values.
/// - paused: The recording is paused and can be resumed later.
/// - stopped: The recording is stopped and can be discarded or saved.
/// - finished: The recording is finished and has a boolean value indicating whether it was successful or not.
/// - error: The recording encountered an error and has an EquatableErrorWrapper as an associated value.
public enum RecordingState: Equatable {
  case recording(duration: TimeInterval, power: Float)
  case paused
  case stopped
  case finished(Bool)
  case error(EquatableErrorWrapper)
}
