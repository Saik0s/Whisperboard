import Foundation

// MARK: - PlaybackPosition

struct PlaybackPosition {
  let currentTime: TimeInterval
  let duration: TimeInterval

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
