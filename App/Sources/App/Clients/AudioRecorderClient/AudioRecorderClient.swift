import AppDevUtils
import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import XCTestDynamicOverlay

// MARK: - AudioRecorderClient

struct AudioRecorderClient {
  var currentTime: @Sendable () async -> TimeInterval
  var requestRecordPermission: @Sendable () async -> Bool

  var recordingState: @Sendable () async -> AsyncStream<RecordingState>
  var startRecording: @Sendable (URL) async -> Void
  var stopRecording: @Sendable () async -> Void
  var pauseRecording: @Sendable () async -> Void
  var continueRecording: @Sendable () async -> Void
  var removeCurrentRecording: @Sendable () async -> Void

  var availableMicrophones: @Sendable () async throws -> AsyncStream<[Microphone]>
  var setMicrophone: @Sendable (Microphone) async throws -> Void
  var currentMicrophone: @Sendable () async throws -> Microphone?
}

// MARK: DependencyKey

extension AudioRecorderClient: DependencyKey {
  static var liveValue: Self {
    let audioRecorder = AudioRecorder()
    return Self(
      currentTime: { await audioRecorder.currentTime },
      requestRecordPermission: { await audioRecorder.requestPermission() },
      recordingState: { await audioRecorder.recordingStateSubject.asAsyncStream() },
      startRecording: { url in await audioRecorder.start(url: url) },
      stopRecording: { await audioRecorder.stop() },
      pauseRecording: { await audioRecorder.pause() },
      continueRecording: { await audioRecorder.continue() },
      removeCurrentRecording: { await audioRecorder.removeCurrentRecording() },
      availableMicrophones: { try await audioRecorder.availableMicrophones() },
      setMicrophone: { microphone in try await audioRecorder.setMicrophone(microphone) },
      currentMicrophone: { try await audioRecorder.currentMicrophone() }
    )
  }
}

extension DependencyValues {
  var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClient.self] }
    set { self[AudioRecorderClient.self] = newValue }
  }
}

// MARK: - AudioRecorderError

enum AudioRecorderError: Error {
  case somethingWrong
}

// MARK: - AudioRecorder

private actor AudioRecorder {
  let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16000.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
  ]

  var recorder: AVAudioRecorder?
  var isSessionActive = false
  let recordingStateSubject = ReplaySubject<RecordingState, Never>(1)
  @MainActor  var timer: Timer?

  lazy var delegate: Delegate = .init(
    didFinishRecording: { [recordingStateSubject] successfully in
      log.info("didFinishRecording: \(successfully)")
      recordingStateSubject.send(.finished(successfully))
      // try? AVAudioSession.sharedInstance().setActive(false)
    },
    encodeErrorDidOccur: { [recordingStateSubject] error in
      log.info("encodeErrorDidOccur: \(error?.localizedDescription ?? "nil")")
      recordingStateSubject.send(.error(error?.equatable ?? AudioRecorderError.somethingWrong.equatable))
      // try? AVAudioSession.sharedInstance().setActive(false)
    }
  )

  var currentTime: TimeInterval {
    guard let recorder, recorder.isRecording else { return 0 }
    return recorder.currentTime
  }

  func requestPermission() async -> Bool {
    await withUnsafeContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  func activateSession() throws {
    log.info("")
    guard !isSessionActive else { return }
    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
    try AVAudioSession.sharedInstance().setActive(true)
    isSessionActive = true
  }

  func stop() {
    log.info("")
    DispatchQueue.main.async { [weak self] in
      self?.timer?.invalidate()
    }
    recorder?.stop()
    recorder = nil
    // try? AVAudioSession.sharedInstance().setActive(false)
    // isSessionActive = false
  }

  func start(url: URL) {
    log.info("")
    if recorder?.isRecording == true {
      removeCurrentRecording()
    }

    recordingStateSubject.send(.recording(duration: 0, power: 0))

    do {
      try activateSession()
      let recorder = try AVAudioRecorder(url: url, settings: settings)
      self.recorder = recorder
      recorder.delegate = delegate
      recorder.isMeteringEnabled = true
      recorder.record()

      DispatchQueue.main.async { [weak self] in
        self?.timer = .scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] timer in
          guard let self, let recorder = self.recorder else {
            timer.invalidate()
            return
          }

          guard recorder.isRecording else { return }

          recorder.updateMeters()
          self.recordingStateSubject.send(.recording(
            duration: recorder.currentTime,
            power: recorder.averagePower(forChannel: 0)
          ))
        }
      }
    } catch {
      log(error)
      recordingStateSubject.send(.error(error.equatable))
    }
  }

  func pause() {
    log.info("")
    recorder?.pause()
  }

  func `continue`() {
    log.info("")
    recorder?.record()
  }

  func removeCurrentRecording() {
    log.info("")
    DispatchQueue.main.async { [weak self] in
      self?.timer?.invalidate()
    }
    recorder?.stop()
    recorder?.deleteRecording()
    recorder = nil
  }

  func availableMicrophones() async throws -> AsyncStream<[Microphone]> {
    let updateStream = AsyncStream<[Microphone]>(
      NotificationCenter.default
        .notifications(named: AVAudioSession.routeChangeNotification)
        .map { _ -> [Microphone] in
          AVAudioSession.sharedInstance().availableInputs?.map(Microphone.init) ?? []
        }
    )

    try activateSession()

    return AsyncStream([Microphone].self) { continuation in
      let microphones = AVAudioSession.sharedInstance().availableInputs?.map(Microphone.init) ?? []
      continuation.yield(microphones)

      Task {
        for await microphones in updateStream {
          continuation.yield(microphones)
        }
      }
    }
  }

  func setMicrophone(_ microphone: Microphone) async throws {
    log.info("microphone: \(microphone)")
    try activateSession()
    try AVAudioSession.sharedInstance().setPreferredInput(microphone.port)
  }

  func currentMicrophone() async throws -> Microphone? {
    try activateSession()
    return AVAudioSession.sharedInstance().currentRoute.inputs.first.map(Microphone.init)
  }
}

// MARK: - Delegate

private final class Delegate: NSObject, AVAudioRecorderDelegate, Sendable {
  let didFinishRecording: @Sendable (_ successfully: Bool) -> Void
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
