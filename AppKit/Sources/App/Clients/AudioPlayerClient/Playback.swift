import Foundation

// MARK: - PlaybackPosition

struct PlaybackPosition {
  /// A constant that represents the current time in seconds since the reference date.
  ///
  /// - note: The reference date is 1 January 2001, at 12:00 a.m. GMT.
  let currentTime: TimeInterval
  /// A property that represents the duration of an event or action in seconds.
  ///
  /// - note: The value of this property is always non-negative.
  let duration: TimeInterval

  /// Returns the progress of the current playback as a fraction of the total duration.
  ///
  /// - returns: A `Double` value between 0 and 1, where 0 means the playback has not started and 1 means the playback has
  /// finished.
  var progress: Double { currentTime / duration }
}

// MARK: - PlaybackState

enum PlaybackState {
  case playing(PlaybackPosition)
  case pause(PlaybackPosition)
  case stop
  case error(Error?)
  case finish(successful: Bool)
}
