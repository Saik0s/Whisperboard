
import AVFoundation
import ComposableArchitecture
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
      recordingState: { audioRecorder.recordingStateSubject.asAsyncStream() },
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
  var recorder: AVAudioRecorder?
  let recordingStateSubject = ReplaySubject<RecordingState, Never>(1)
  var task: Task<Void, Error>?
  var selectedMicrophone: Microphone?
  @Dependency(\.audioSession) var audioSession: AudioSessionClient

  lazy var delegate: Delegate = .init(
    didFinishRecording: { [audioSession, recordingStateSubject] successfully in
      log.info("didFinishRecording: \(successfully)")
      try? audioSession.disable(.record, true)
      recordingStateSubject.send(.finished(successfully))
    },
    encodeErrorDidOccur: { [audioSession, recordingStateSubject] error in
      log.info("encodeErrorDidOccur: \(error?.localizedDescription ?? "nil")")
      try? audioSession.disable(.record, true)
      recordingStateSubject.send(.error(error?.equatable ?? AudioRecorderError.somethingWrong.equatable))
    }
  )

  var currentTime: TimeInterval {
    recorder?.currentTime ?? 0
  }

  func requestPermission() async -> Bool {
    await withUnsafeContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  func stop() {
    log.info("")
    task?.cancel()
    recorder?.stop()
    recorder = nil
  }

  func start(url: URL) {
    log.info("")
    if recorder?.isRecording == true {
      removeCurrentRecording()
    }

    recordingStateSubject.send(.recording(duration: 0, power: 0))

    do {
      try audioSession.enable(.record, true)
      try AVAudioSession.sharedInstance().setPreferredInput(selectedMicrophone?.port)
      let recorder = try AVAudioRecorder(url: url, settings: AudioRecorderSettings.whisper)
      self.recorder = recorder
      recorder.delegate = delegate
      recorder.isMeteringEnabled = true
      recorder.record()

      task = Task { [weak self] in
        while true {
          await self?.updateMeters()
          try await Task.sleep(seconds: 0.025)
        }
      }
    } catch {
      log.error(error)
      recordingStateSubject.send(.error(error.equatable))
    }
  }

  func pause() {
    log.info("pause")
    recorder?.pause()
  }

  func `continue`() {
    log.info("continue")
    recorder?.record()
  }

  func removeCurrentRecording() {
    log.info("")
    task?.cancel()
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

    try audioSession.enable(.record, false)

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
    selectedMicrophone = microphone
    try AVAudioSession.sharedInstance().setPreferredInput(microphone.port)
  }

  func currentMicrophone() async throws -> Microphone? {
    AVAudioSession.sharedInstance().currentRoute.inputs.first.map(Microphone.init) ?? selectedMicrophone
  }

  private func updateMeters() async {
    guard let recorder else {
      task?.cancel()
      return
    }

    guard recorder.isRecording else { return }

    recorder.updateMeters()
    recordingStateSubject.send(.recording(
      duration: recorder.currentTime,
      power: recorder.averagePower(forChannel: 0)
    ))
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
