import Foundation

@preconcurrency import AVFoundation

final class AudioPlayer: NSObject, AVAudioPlayerDelegate, Sendable {
  let didFinishPlaying: @Sendable (Bool) -> Void
  let decodeErrorDidOccur: @Sendable (Error?) -> Void
  let player: AVAudioPlayer

  init(
    url: URL,
    didFinishPlaying: @escaping @Sendable (Bool) -> Void,
    decodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
  ) throws {
    self.didFinishPlaying = didFinishPlaying
    self.decodeErrorDidOccur = decodeErrorDidOccur
    player = try AVAudioPlayer(contentsOf: url)
    super.init()
    player.delegate = self
  }

  func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully flag: Bool) {
    didFinishPlaying(flag)
  }

  func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error: Error?) {
    decodeErrorDidOccur(error)
  }
}
