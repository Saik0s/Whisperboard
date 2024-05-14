import AVFoundation
import ComposableArchitecture
import ConcurrencyExtras
import Dependencies
import Foundation
import XCTestDynamicOverlay

// MARK: - AudioRecorderSettings

enum AudioRecorderSettings {
  static let whisper: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 16000.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
  ]
}

// MARK: - AudioRecorderClient

struct AudioRecorderClient {
  var currentTime: @Sendable () async -> TimeInterval
  var requestRecordPermission: @Sendable () async -> Bool

  var startRecording: @Sendable (URL) async -> AsyncStream<RecordingState>
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
      startRecording: { url in await audioRecorder.start(url: url) },
      stopRecording: { await audioRecorder.stop() },
      pauseRecording: { await audioRecorder.pause() },
      continueRecording: { await audioRecorder.continue() },
      removeCurrentRecording: { await audioRecorder.removeCurrentRecording() },
      availableMicrophones: { try await audioRecorder.availableMicrophones() },
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

// MARK: - AudioRecorderError

enum AudioRecorderError: Error {
  case somethingWrong
}

// MARK: - AudioRecorder

private actor AudioRecorder {
  var recorder: AVAudioRecorder?
  var recordingStateContinuation: AsyncStream<RecordingState>.Continuation?
  var task: Task<Void, Error>?
  var isInterrupted = false

  @Dependency(\.audioSession) var audioSession: AudioSessionClient

  lazy var delegate: Delegate = .init(
    didFinishRecording: { [weak self] successfully in
      logs.info("didFinishRecording: \(successfully)")
      Task(priority: .background) { [weak self] in
        await self?.disableSession()
        await self?.recordingStateContinuation?.yield(RecordingState.finished(successfully))
        await self?.recordingStateContinuation?.finish()
      }
    },
    encodeErrorDidOccur: { [weak self] error in
      logs.info("encodeErrorDidOccur: \(error?.localizedDescription ?? "nil")")
      Task(priority: .background) { [weak self] in
        await self?.disableSession()
        await self?.recordingStateContinuation?.yield(RecordingState.error(error?.equatable ?? AudioRecorderError.somethingWrong.equatable))
        await self?.recordingStateContinuation?.finish()
      }
    },
    interruptionOccurred: { [weak self, audioSession] type, userInfo in
      logs.info("interruptionOccurred: \(type)")
      Task(priority: .background) { [weak self] in
        await self?.processInterruption(type: type, userInfo: userInfo)
      }
    }
  )

  var currentTime: TimeInterval {
    recorder?.currentTime ?? 0
  }

  func requestPermission() async -> Bool {
    await audioSession.requestRecordPermission()
  }

  func stop() {
    logs.info("stop")
    task?.cancel()
    recorder?.stop()
    recorder = nil
  }

  func start(url: URL) -> AsyncStream<RecordingState> {
    logs.info("Start recording to: \(url)")
    if recorder?.isRecording == true {
      removeCurrentRecording()
    }

    let (stream, continuation) = AsyncStream<RecordingState>.makeStream(bufferingPolicy: .unbounded)
    recordingStateContinuation = continuation

    continuation.yield(.recording(duration: 0, powers: []))

    do {
      let recorder = try AVAudioRecorder(url: url, settings: AudioRecorderSettings.whisper)
      self.recorder = recorder
      recorder.delegate = delegate
      recorder.isMeteringEnabled = true

      task = Task(priority: .utility) { [weak self] in
        try await self?.audioSession.enable(.record, true)
        await self?.recorder?.record()
        while await self?.recorder != nil && !Task.isCancelled {
          try await self?.updateMeters()
        }
      }
    } catch {
      logs.error("start error: \(error)")
      continuation.yield(.error(error.equatable))
    }

    return stream
  }

  func pause() {
    logs.info("pause")
    recorder?.pause()
    recordingStateContinuation?.yield(.paused)
  }

  func `continue`() {
    logs.info("continue")
    recorder?.record()
  }

  func removeCurrentRecording() {
    logs.info("removeCurrentRecording")
    task?.cancel()
    recorder?.stop()
    recorder?.deleteRecording()
    recorder = nil
  }

  func availableMicrophones() throws -> AsyncStream<[Microphone]> {
    try audioSession.availableMicrophones()
  }

  func setMicrophone(_ microphone: Microphone) throws {
    logs.info("microphone: \(microphone)")
    try audioSession.selectMicrophone(microphone)
  }

  func currentMicrophone() -> Microphone? {
    audioSession.currentMicrophone()
  }

  private func disableSession() {
    do {
      try audioSession.disable(.record, true)
    } catch {
      logs.error("turnOffSession error: \(error)")
    }
  }

  private func updateMeters() async throws {
    guard let recorder else {
      task?.cancel()
      return
    }

    guard recorder.isRecording else { return }

    var powers = [Float]()
    for _ in 0 ..< 10 {
      recorder.updateMeters()
      powers.append(recorder.averagePower(forChannel: 0))
      try await Task.sleep(seconds: 0.01)
    }
    recordingStateContinuation?.yield(.recording(
      duration: recorder.currentTime,
      powers: powers
    ))
  }

  private func processInterruption(type: AVAudioSession.InterruptionType, userInfo: [AnyHashable: Any]) {
    if type == .began {
      if recorder?.isRecording == true {
        pause()
        isInterrupted = true
      }
    } else if type == .ended {
      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
      if options.contains(.shouldResume), isInterrupted {
        `continue`()
      }
      isInterrupted = false
    }
  }
}

// MARK: - Delegate

private final class Delegate: NSObject, AVAudioRecorderDelegate, Sendable {
  let didFinishRecording: @Sendable (_ successfully: Bool) -> Void
  let encodeErrorDidOccur: @Sendable (Error?) -> Void
  let interruptionOccurred: @Sendable (AVAudioSession.InterruptionType, [AnyHashable: Any]) -> Void

  init(
    didFinishRecording: @escaping @Sendable (Bool) -> Void,
    encodeErrorDidOccur: @escaping @Sendable (Error?) -> Void,
    interruptionOccurred: @escaping @Sendable (AVAudioSession.InterruptionType, [AnyHashable: Any]) -> Void
  ) {
    self.didFinishRecording = didFinishRecording
    self.encodeErrorDidOccur = encodeErrorDidOccur
    self.interruptionOccurred = interruptionOccurred
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
  }

  func audioRecorderDidFinishRecording(_: AVAudioRecorder, successfully flag: Bool) {
    didFinishRecording(flag)
  }

  func audioRecorderEncodeErrorDidOccur(_: AVAudioRecorder, error: Error?) {
    encodeErrorDidOccur(error)
  }

  @objc
  private func handleInterruption(notification: Notification) {
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    interruptionOccurred(type, info)
  }
}
