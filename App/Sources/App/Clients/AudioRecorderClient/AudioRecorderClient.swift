import AppDevUtils
import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import XCTestDynamicOverlay

// MARK: - AudioRecorderClient

struct AudioRecorderClient {
  var currentTime: @Sendable () async -> TimeInterval?
  var requestRecordPermission: @Sendable () async -> Bool
  var startRecording: @Sendable (URL) async throws -> Bool
  var stopRecording: @Sendable () async -> Void
  var pauseRecording: @Sendable () async -> Void
  var continueRecording: @Sendable () async -> Void
  var availableMicrophones: @Sendable () async -> AsyncStream<[Microphone]>
  var setMicrophone: @Sendable (Microphone) async throws -> Void
  var currentMicrophone: @Sendable () async -> Microphone?
}

// MARK: DependencyKey

extension AudioRecorderClient: DependencyKey {
  static var liveValue: Self {
    let audioRecorder = AudioRecorder()
    return Self(
      currentTime: { await audioRecorder.currentTime },
      requestRecordPermission: { await AudioRecorder.requestPermission() },
      startRecording: { url in try await audioRecorder.start(url: url) },
      stopRecording: { await audioRecorder.stop() },
      pauseRecording: { await audioRecorder.pause() },
      continueRecording: { await audioRecorder.continue() },
      availableMicrophones: { await audioRecorder.availableMicrophones() },
      setMicrophone: { microphone in try await audioRecorder.setMicrophone(microphone) },
      currentMicrophone: { await audioRecorder.currentMicrophone() }
    )
  }
}

extension DependencyValues {
  var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClient.self] }
    set { self[AudioRecorderClient.self] = newValue }
  }
}

// MARK: - AudioRecorder

private actor AudioRecorder {
  var delegate: Delegate?
  var recorder: AVAudioRecorder?
  var isSessionActive = false

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

  func activateSession() throws {
    guard !isSessionActive else { return }
    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
    try AVAudioSession.sharedInstance().setActive(true)
    isSessionActive = true
  }

  func stop() {
    recorder?.stop()
    // try? AVAudioSession.sharedInstance().setActive(false)
    // isSessionActive = false
  }

  func start(url: URL) async throws -> Bool {
    stop()

    let stream = AsyncThrowingStream<Bool, Error> { continuation in
      do {
        self.delegate = Delegate(
          didFinishRecording: { flag in
            continuation.yield(flag)
            continuation.finish()
            // try? AVAudioSession.sharedInstance().setActive(false)
          },
          encodeErrorDidOccur: { error in
            continuation.finish(throwing: error)
            // try? AVAudioSession.sharedInstance().setActive(false)
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

        try self.activateSession()
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

  func pause() {
    recorder?.pause()
  }

  func `continue`() {
    recorder?.record()
  }

  func availableMicrophones() async -> AsyncStream<[Microphone]> {
    let updateStream = AsyncStream<[Microphone]>(
      NotificationCenter.default
        .notifications(named: AVAudioSession.routeChangeNotification)
        .map { notification -> [Microphone] in
          AVAudioSession.sharedInstance().availableInputs?.map(Microphone.init) ?? []
        }
    )

    return AsyncStream([Microphone].self) { continuation in
      Task {
        do {
          try self.activateSession()
        } catch {
          log.error(error)
        }

        let microphones = AVAudioSession.sharedInstance().availableInputs?.map(Microphone.init) ?? []
        continuation.yield(microphones)

        for await microphones in updateStream {
          continuation.yield(microphones)
        }
      }
    }
  }

  func setMicrophone(_ microphone: Microphone) async throws {
    try AVAudioSession.sharedInstance().setPreferredInput(microphone.port)
  }

  func currentMicrophone() async -> Microphone? {
    AVAudioSession.sharedInstance().currentRoute.inputs.first.map(Microphone.init)
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
