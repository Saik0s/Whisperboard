import Foundation

@preconcurrency import AVFoundation

final class AudioPlayer: NSObject, AVAudioPlayerDelegate, Sendable {
  /// A closure that is executed when a sound finishes playing.
  ///
  /// - parameter didFinish: A boolean value indicating whether the sound finished playing normally or was interrupted.
  /// - returns: Nothing.
  let didFinishPlaying: @Sendable (Bool) -> Void
  /// A closure that handles decoding errors.
  ///
  /// - parameter error: The error that occurred during decoding, or `nil` if no error occurred.
  /// - returns: Nothing.
  let decodeErrorDidOccur: @Sendable (Error?) -> Void
  /// A property that holds an instance of `AVAudioPlayer`.
  ///
  /// - note: The `AVAudioPlayer` class lets you play sound files of various formats from your app’s main bundle or from a
  /// location specified by a URL.
  let player: AVAudioPlayer

  /// Initializes an audio player with a given URL and callback functions.
  ///
  /// - parameter url: The URL of the audio file to be played.
  /// - parameter didFinishPlaying: A closure that is called when the audio player finishes playing or is stopped.
  /// - parameter decodeErrorDidOccur: A closure that is called when an error occurs during decoding of the audio file.
  /// - throws: An error if the audio player cannot be initialized with the given URL.
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

  /// Notifies the delegate that the audio player has finished playing a sound.
  ///
  /// - parameter player: The audio player that finished playing.
  /// - parameter flag: A Boolean value that indicates whether the sound was played successfully or not.
  /// - note: This method is called when the audio player finishes playing due to reaching the end of the sound file or an
  /// interruption.
  func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully flag: Bool) {
    didFinishPlaying(flag)
  }

  /// Handles the decoding error that occurred while playing an audio file.
  ///
  /// - parameter _: The audio player that encountered the error.
  /// - parameter error: The error that occurred, or `nil` if unknown.
  /// - calls: `decodeErrorDidOccur(_:)` to perform the actual error handling.
  func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error: Error?) {
    decodeErrorDidOccur(error)
  }
}
