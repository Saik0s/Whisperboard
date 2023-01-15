//
// LiveAudioRecorderClient.swift
//

import AVFoundation
import ComposableArchitecture // TODO: Should `UncheckedSendable` live in `Dependencies`?

// MARK: - AudioRecorderClient + DependencyKey

extension AudioRecorderClient: DependencyKey {
  static var liveValue: Self {
    let audioRecorder = AudioRecorder()
    return Self(
      currentTime: { await audioRecorder.currentTime },
      requestRecordPermission: { await AudioRecorder.requestPermission() },
      startRecording: { url in try await audioRecorder.start(url: url) },
      stopRecording: { await audioRecorder.stop() }
    )
  }
}

// MARK: - AudioRecorder

private actor AudioRecorder {
  var delegate: Delegate?
  var recorder: AVAudioRecorder?

  var currentTime: TimeInterval? {
    guard let recorder,
          recorder.isRecording
    else { return nil }
    return recorder.currentTime
  }

  static func requestPermission() async -> Bool {
    await withUnsafeContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  static func activateSession() throws {
    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
    try AVAudioSession.sharedInstance().setActive(true)
  }

  func stop() {
    recorder?.stop()
    try? AVAudioSession.sharedInstance().setActive(false)
  }

  func start(url: URL) async throws -> Bool {
    stop()

    let stream = AsyncThrowingStream<Bool, Error> { continuation in
      do {
        self.delegate = Delegate(
          didFinishRecording: { flag in
            continuation.yield(flag)
            continuation.finish()
            try? AVAudioSession.sharedInstance().setActive(false)
          },
          encodeErrorDidOccur: { error in
            continuation.finish(throwing: error)
            try? AVAudioSession.sharedInstance().setActive(false)
          }
        )
        let recorder = try AVAudioRecorder(
          url: url,
          settings: [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
          ]
        )
        self.recorder = recorder
        recorder.delegate = self.delegate

        continuation.onTermination = { [recorder = UncheckedSendable(recorder)] _ in
          recorder.wrappedValue.stop()
        }

        try AudioRecorder.activateSession()
        self.recorder?.record()
      } catch {
        continuation.finish(throwing: error)
      }
    }

    for try await didFinish in stream {
      return didFinish
    }
    throw CancellationError()
  }
}

// MARK: - Delegate

private final class Delegate: NSObject, AVAudioRecorderDelegate, Sendable {
  let didFinishRecording: @Sendable (Bool) -> Void
  let encodeErrorDidOccur: @Sendable (Error?)
    -> Void

  init(
    didFinishRecording: @escaping @Sendable (Bool) -> Void,
    encodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
  ) {
    self.didFinishRecording = didFinishRecording
    self.encodeErrorDidOccur = encodeErrorDidOccur
  }

  func audioRecorderDidFinishRecording(_: AVAudioRecorder, successfully flag: Bool) {
    didFinishRecording(flag)
  }

  func audioRecorderEncodeErrorDidOccur(_: AVAudioRecorder, error: Error?) {
    encodeErrorDidOccur(error)
  }
}
