import AVFoundation
import Dependencies
import Foundation

// MARK: - AudioPlayerClient

struct AudioPlayerClient {
  var play: @Sendable (URL) -> AsyncStream<PlaybackState>
  var seekProgress: @Sendable (Double) async -> Void
  var pause: @Sendable () async -> Void
  var stop: @Sendable () async -> Void
  var speed: @Sendable (Float) async -> Void
}

// MARK: DependencyKey

extension AudioPlayerClient: DependencyKey {
  class Context {
    var audioPlayer: AudioPlayer?
    var continuation: AsyncStream<PlaybackState>.Continuation?

    init() {}
  }

  static let liveValue: AudioPlayerClient = {
    let context = Context()

    return AudioPlayerClient(
      play: { url in
        let stream = AsyncStream<PlaybackState> { continuation in
          do {
            context.audioPlayer = try AudioPlayer(
              url: url,
              didFinishPlaying: { successful in
                continuation.yield(.finish(successful: successful))
                continuation.finish()
              },
              decodeErrorDidOccur: { error in
                continuation.yield(.error(error))
                continuation.finish()
              }
            )
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)

            context.audioPlayer?.player.play()
            let timerTask = Task {
              let clock = ContinuousClock()
              for await _ in clock.timer(interval: .milliseconds(100)) {
                guard context.audioPlayer?.player.isPlaying == true else { continue }

                let position = PlaybackPosition(
                  currentTime: context.audioPlayer?.player.currentTime ?? 0,
                  duration: context.audioPlayer?.player.duration ?? 0
                )
                continuation.yield(.playing(position))
              }
            }
            continuation.onTermination = { _ in
              context.audioPlayer?.player.stop()
              timerTask.cancel()
            }

          } catch {
            continuation.yield(.error(error))
            continuation.finish()
          }
        }
        return stream
      },
      seekProgress: { progress in
        if let player = context.audioPlayer?.player {
          let time = player.duration * progress
          player.currentTime = time
          context.continuation?.yield(.playing(PlaybackPosition(
            currentTime: context.audioPlayer?.player.currentTime ?? 0,
            duration: context.audioPlayer?.player.duration ?? 0
          )))
        }
      },
      pause: {
        context.audioPlayer?.player.pause()
        context.continuation?.yield(.pause(PlaybackPosition(
          currentTime: context.audioPlayer?.player.currentTime ?? 0,
          duration: context.audioPlayer?.player.duration ?? 0
        )))
      },
      stop: {
        context.audioPlayer?.player.stop()
        context.continuation?.yield(.stop)
      },
      speed: { speed in
        context.audioPlayer?.player.rate = speed
      }
    )
  }()
}

extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClient.self] }
    set { self[AudioPlayerClient.self] = newValue }
  }
}
