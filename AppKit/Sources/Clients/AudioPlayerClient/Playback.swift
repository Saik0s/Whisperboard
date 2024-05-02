import Foundation

// MARK: - PlaybackPosition

struct PlaybackPosition: Equatable {
  let currentTime: TimeInterval
  let duration: TimeInterval

  var progress: Double { currentTime / duration }
}

// MARK: - PlaybackState

enum PlaybackState: Equatable {
  case playing(PlaybackPosition)
  case pause(PlaybackPosition)
  case stop
  case error(EquatableError?)
  case finish(successful: Bool)
}
