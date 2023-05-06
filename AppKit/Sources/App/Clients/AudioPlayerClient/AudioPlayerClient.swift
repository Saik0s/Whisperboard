import AVFoundation
import Dependencies
import Foundation

// MARK: - AudioPlayerClient

struct AudioPlayerClient {
  /// Returns an asynchronous stream of playback states for a given URL.
  ///
  /// - parameter url: The URL of the media to be played.
  /// - returns: An `AsyncStream` that emits `PlaybackState` values as the media playback progresses.
  var play: @Sendable (URL) -> AsyncStream<PlaybackState>
  /// A property that sets the playback position of a media player.
  ///
  /// - parameter progress: A value between 0 and 1 that represents the percentage of the media duration to seek to.
  /// - returns: An `async` task that performs the seek operation.
  var seekProgress: @Sendable (Double) async -> Void
  /// Pauses the execution of an asynchronous task.
  ///
  /// - note: This function is marked with the `@Sendable` attribute, which means it can be safely called from any actor
  /// or concurrency domain.
  var pause: @Sendable () async -> Void
  /// A property that holds a closure that stops the execution of an asynchronous task.
  ///
  /// - note: This property is `@Sendable`, which means it can be safely passed across actors or threads.
  /// - seealso: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html#ID638
  var stop: @Sendable () async -> Void
  /// Sets the speed of a `@Sendable` object asynchronously.
  ///
  /// - parameter speed: A floating-point value representing the desired speed in meters per second.
  /// - returns: A `Void` value indicating the completion of the operation.
  var speed: @Sendable (Float) async -> Void
}

// MARK: DependencyKey

extension AudioPlayerClient: DependencyKey {
  class Context {
    /// An optional instance of `AudioPlayer` that can play audio files.
    ///
    /// - note: This property is `nil` by default and must be initialized with a valid `URL` or `Data` object before
    /// playing.
    var audioPlayer: AudioPlayer?

    var continuation: AsyncStream<PlaybackState>.Continuation?

    init() {}
  }

  /// Returns an `AudioPlayerClient` instance that can play, seek, pause, stop and adjust the speed of an audio file from
  /// a given URL.
  ///
  /// - parameter play: A closure that takes a URL and returns an `AsyncStream` of `PlaybackState` values. The stream
  /// emits the current playback position, finish status or error of the audio player.
  /// - parameter seekProgress: A closure that takes a progress value between 0 and 1 and sets the current time of the
  /// audio player accordingly. It also emits the updated playback position to the stream.
  /// - parameter pause: A closure that pauses the audio player and emits the current playback position and pause state to
  /// the stream.
  /// - parameter stop: A closure that stops the audio player and emits the stop state to the stream.
  /// - parameter speed: A closure that takes a speed value and sets the rate of the audio player accordingly.
  /// - returns: An `AudioPlayerClient` instance with the specified closures.
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
