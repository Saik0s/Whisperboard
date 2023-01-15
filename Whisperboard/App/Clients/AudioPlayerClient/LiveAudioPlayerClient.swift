//
// LiveAudioPlayerClient.swift
//

@preconcurrency import AVFoundation
import Dependencies

// MARK: - AudioPlayerClient + DependencyKey

extension AudioPlayerClient: DependencyKey {
  static let liveValue = Self { url in
    let stream = AsyncThrowingStream<Bool, Error> { continuation in
      do {
        let delegate = try Delegate(
          url: url,
          didFinishPlaying: { successful in
            continuation.yield(successful)
            continuation.finish()
          },
          decodeErrorDidOccur: { error in
            continuation.finish(throwing: error)
          }
        )
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try AVAudioSession.sharedInstance().setActive(true)
        delegate.player.play()
        continuation.onTermination = { _ in
          delegate.player.stop()
        }
      } catch {
        continuation.finish(throwing: error)
      }
    }
    return try await stream.first(where: { _ in true }) ?? false
  }
}

// MARK: - Delegate

private final class Delegate: NSObject, AVAudioPlayerDelegate, Sendable {
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
