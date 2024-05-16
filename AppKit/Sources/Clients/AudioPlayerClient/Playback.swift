import Foundation

// MARK: - PlaybackPosition

struct PlaybackPosition: Equatable {
  let currentTime: TimeInterval
  let duration: TimeInterval

  var progress: Double { currentTime / duration }

  static func == (lhs: PlaybackPosition, rhs: PlaybackPosition) -> Bool {
    return lhs.currentTime.rounded(toPlaces: 2) == rhs.currentTime.rounded(toPlaces: 2) &&
           lhs.duration.rounded(toPlaces: 2) == rhs.duration.rounded(toPlaces: 2)
  }
}

// MARK: - PlaybackState

enum PlaybackState: Equatable {
  case playing(PlaybackPosition)
  case pause(PlaybackPosition)
  case stop
  case error(EquatableError?)
  case finish(successful: Bool)
}
