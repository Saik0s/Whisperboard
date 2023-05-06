import AppDevUtils
import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import XCTestDynamicOverlay

// MARK: - AudioRecorderSettings

/// An enumeration that defines a set of audio recorder settings for different recording scenarios.
///
/// Each case of the enumeration is a dictionary that contains the keys and values for configuring an `AVAudioRecorder`
/// instance. The keys are constants defined in the `AVFoundation` framework, and the values are appropriate for the
/// corresponding recording scenario.
///
/// For example, the `whisper` case contains settings for recording a whispering voice with a high-quality linear PCM
/// format, a sample rate of 16 kHz, a single channel, and a high encoder audio quality.
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
  /// Returns the current time interval since the reference date.
  ///
  /// - note: This function is marked as `@Sendable` and `async`, which means it can be safely called from any concurrency
  /// context and may suspend its execution until the result is available.
  /// - returns: A `TimeInterval` value representing the number of seconds since 00:00:00 UTC on 1 January 2001.
  var currentTime: @Sendable () async -> TimeInterval
  /// Requests the user's permission to record audio using the microphone.
  ///
  /// - returns: A boolean value indicating whether the permission was granted or not. The value is `true` if the
  /// permission was granted, and `false` otherwise. This function is asynchronous and must be awaited.
  var requestRecordPermission: @Sendable () async -> Bool

  /// Returns an `AsyncStream` of `RecordingState` values that represents the current state of a recording session.
  ///
  /// - parameter recordingState: A `@Sendable` closure that asynchronously produces `RecordingState` values.
  /// - returns: An `AsyncStream` of `RecordingState` values that can be consumed by an `AsyncSequence` iterator.
  var recordingState: @Sendable () async -> AsyncStream<RecordingState>
  /// Starts recording audio and saves it to the specified URL.
  ///
  /// - parameter url: The URL where the audio file should be stored.
  /// - throws: An error if the recording fails or the URL is invalid.
  /// - note: This function is marked with `@Sendable` to indicate that it can be called from any actor context.
  var startRecording: @Sendable (URL) async -> Void
  /// Stops the recording of the current audio session.
  ///
  /// - note: This function is marked as `@Sendable` to allow it to be called from any actor or task context.
  /// - throws: An `AudioError` if the recording cannot be stopped or saved.
  var stopRecording: @Sendable () async -> Void
  /// Pauses the recording of an audio session.
  ///
  /// This function is marked as `@Sendable` to allow it to be called from any actor or task context.
  /// This function is marked as `async` to indicate that it may perform some asynchronous work before returning.
  /// This function does not take any parameters or return any value.
  var pauseRecording: @Sendable () async -> Void
  /// A closure that continues the recording of an audio session asynchronously.
  ///
  /// - note: This closure is marked with the `@Sendable` attribute to ensure that it can be safely passed across
  /// concurrency domains.
  /// - throws: An `Error` if the recording fails or is interrupted.
  var continueRecording: @Sendable () async -> Void
  /// Removes the current recording from the device storage.
  ///
  /// This function is marked with the `@Sendable` attribute to indicate that it can be safely called from concurrent
  /// contexts.
  /// It is also an `async` function that returns a `Void` value, meaning that it does not produce any result and can be
  /// awaited using the `await` keyword.
  ///
  /// - note: This function may throw an error if the removal operation fails.
  var removeCurrentRecording: @Sendable () async -> Void

  /// Returns an `AsyncStream` of available microphones on the device.
  ///
  /// - throws: An error if the microphone access is denied or unavailable.
  /// - returns: An `AsyncStream` that asynchronously produces an array of `Microphone` objects.
  var availableMicrophones: @Sendable () async throws -> AsyncStream<[Microphone]>
  /// Sets the microphone for the current audio session.
  ///
  /// - parameter microphone: The microphone to use for recording audio.
  /// - throws: An error if the microphone is unavailable or incompatible.
  /// - note: This function is `@Sendable` and can be called from any actor or task.
  var setMicrophone: @Sendable (Microphone) async throws -> Void
  /// Returns the current microphone that is available for recording audio.
  ///
  /// - throws: An error if the microphone is not accessible or authorized.
  /// - returns: A `Microphone` object that represents the current microphone, or `nil` if none is available.
  var currentMicrophone: @Sendable () async throws -> Microphone?
}

// MARK: DependencyKey

extension AudioRecorderClient: DependencyKey {
  /// Returns a live value of the `Self` type that wraps an `AudioRecorder` instance.
  ///
  /// - returns: A `Self` value that provides access to the following properties and methods of the `AudioRecorder`:
  /// - `currentTime`: The current time of the recording in seconds, as an `async` property.
  /// - `requestRecordPermission`: A method that requests permission to record audio from the user, as an `async` function
  /// that returns a `Bool`.
  /// - `recordingState`: A property that returns an `AsyncStream` of `RecordingState` values, indicating the current
  /// state of the recording.
  /// - `startRecording`: A method that starts recording audio to the given URL, as an `async` function that takes a `URL`
  /// parameter.
  /// - `stopRecording`: A method that stops recording audio and saves the file, as an `async` function.
  /// - `pauseRecording`: A method that pauses recording audio, as an `async` function.
  /// - `continueRecording`: A method that resumes recording audio after pausing, as an `async` function.
  /// - `removeCurrentRecording`: A method that deletes the current recording file, as an `async` function.
  /// - `availableMicrophones`: A property that returns an array of available microphones, as an `async throws` function.
  /// - `setMicrophone`: A method that sets the current microphone to the given one, as an `async throws` function that
  /// takes a `Microphone` parameter.
  /// - `currentMicrophone`: A property that returns the current microphone, as an `async throws` function.
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
  /// A computed property that accesses the `AudioRecorderClient` instance stored in the environment.
  ///
  /// - get: Returns the `AudioRecorderClient` instance associated with this environment.
  /// - set: Sets the `AudioRecorderClient` instance associated with this environment to the given value.
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

/// A type that manages the recording of audio from the device's microphone and saves it to a file.
///
/// This type uses an `AVAudioRecorder` instance to record audio and a `ReplaySubject` to emit the current recording
/// state to subscribers. It also uses a timer to update the audio level meters periodically. It provides methods to
/// start, pause, resume and stop the recording, as well as to request permission to use the microphone and to get the
/// list of available microphones asynchronously.
///
/// - note: This type requires the `AVFoundation` and `Combine` frameworks to work. It also uses some features from
/// Swift 5.5, such as async/await and `AsyncStream`.
///
/// - seealso: The `Microphone` struct that represents an input device for the audio session.
private actor AudioRecorder {
  /// A property that holds a reference to an audio recorder object.
  ///
  /// - note: This property is optional and may be nil if the recorder is not initialized or has been deallocated.
  var recorder: AVAudioRecorder?
  /// A Boolean value indicating whether the session is active or not.
  ///
  /// This property is set to `true` when the session starts and `false` when the session ends.
  var isSessionActive = false
  /// Creates a `ReplaySubject` that emits the most recent `RecordingState` value to new subscribers.
  ///
  /// - parameter bufferSize: The size of the buffer to store the latest value. Must be at least 1.
  /// - returns: A `ReplaySubject` that can be used to observe and update the recording state.
  let recordingStateSubject = ReplaySubject<RecordingState, Never>(1)
  /// A timer that runs on the main actor.
  ///
  /// - note: This property is marked with `@MainActor` to ensure that it is only accessed from the main thread or a
  /// function that is isolated to the main actor. This helps to avoid race conditions and data inconsistencies when using
  /// the timer.
  @MainActor var timer: Timer?

  /// A lazy property that creates and returns a `Delegate` instance with two closure parameters.
  ///
  /// - parameter didFinishRecording: A closure that is called when the recording finishes successfully or unsuccessfully.
  /// It takes a `Bool` parameter indicating the success status and updates the `recordingStateSubject` accordingly.
  /// - parameter encodeErrorDidOccur: A closure that is called when an encoding error occurs during the recording. It
  /// takes an optional `Error` parameter and updates the `recordingStateSubject` with the appropriate error value.
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

  /// Returns the current time of the recorder, or zero if the recorder is nil.
  ///
  /// - returns: A `TimeInterval` representing the elapsed time since the recorder started recording.
  var currentTime: TimeInterval {
    recorder?.currentTime ?? 0
  }

  /// Requests permission to use the device's microphone.
  ///
  /// - returns: A `Bool` value indicating whether the permission was granted or not. The value is `true` if the
  /// permission was granted and `false` otherwise.
  /// - note: This function uses an asynchronous continuation to resume the execution after the user responds to the
  /// permission request.
  func requestPermission() async -> Bool {
    await withUnsafeContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  /// Activates the audio session with the specified category, mode and options.
  ///
  /// - throws: An error if the audio session cannot be set or activated.
  /// - note: This function does nothing if the session is already active.
  func activateSession() throws {
    log.info("")
    guard !isSessionActive else { return }
    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
    try AVAudioSession.sharedInstance().setActive(true)
    isSessionActive = true
  }

  /// Stops the recording and invalidates the timer.
  ///
  /// - note: This function should be called on the main thread.
  /// - postcondition: The `recorder` property is set to `nil` after stopping.
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

  /// Starts recording audio from the microphone and saves it to the given URL.
  ///
  /// - parameter url: The URL where the audio file will be saved.
  /// - precondition: The recorder must not be already recording.
  /// - postcondition: The recorder will be set to the newly created `AVAudioRecorder` instance and a timer will be
  /// scheduled to update the meters periodically.
  /// - throws: An error if the session cannot be activated or the recorder cannot be initialized with the given URL and
  /// settings.
  func start(url: URL) {
    log.info("")
    if recorder?.isRecording == true {
      removeCurrentRecording()
    }

    recordingStateSubject.send(.recording(duration: 0, power: 0))

    do {
      try activateSession()
      let recorder = try AVAudioRecorder(url: url, settings: AudioRecorderSettings.whisper)
      self.recorder = recorder
      recorder.delegate = delegate
      recorder.isMeteringEnabled = true
      recorder.record()

      DispatchQueue.main.async { [weak self] in
        self?.timer = .scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] _ in
          Task { [weak self] in
            await self?.updateMeters()
          }
        }
      }
    } catch {
      log.error(error)
      recordingStateSubject.send(.error(error.equatable))
    }
  }

  /// Pauses the recording session and logs an empty message.
  ///
  /// - precondition: The recorder must not be nil.
  /// - postcondition: The recorder's state is changed to paused.
  func pause() {
    log.info("")
    recorder?.pause()
  }

  /// Starts or resumes recording audio.
  ///
  /// - precondition: The `recorder` property must not be `nil`.
  /// - postcondition: The `recorder`'s `isRecording` property will be `true`.
  /// - note: This function will log an empty message to the console for debugging purposes.
  func `continue`() {
    log.info("")
    recorder?.record()
  }

  /// Stops and deletes the current recording if any.
  ///
  /// - note: This function must be called on the main thread. It invalidates the timer and sets the recorder to nil.
  func removeCurrentRecording() {
    log.info("")
    DispatchQueue.main.async { [weak self] in
      self?.timer?.invalidate()
    }
    recorder?.stop()
    recorder?.deleteRecording()
    recorder = nil
  }

  /// Returns an `AsyncStream` of available microphones.
  ///
  /// This function activates the audio session and then creates an `AsyncStream` that yields the current list of
  /// available microphones. The stream also listens for changes in the audio route and updates the list accordingly.
  ///
  /// - throws: An error if the audio session activation fails.
  /// - returns: An `AsyncStream` of `[Microphone]` values.
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

  /// Sets the preferred input device for the audio session to the given microphone.
  ///
  /// - parameter microphone: The microphone to use as the input device.
  /// - throws: An error if the session cannot be activated or the input device cannot be set.
  /// - note: This function is asynchronous and requires Swift concurrency.
  func setMicrophone(_ microphone: Microphone) async throws {
    log.info("microphone: \(microphone)")
    try activateSession()
    try AVAudioSession.sharedInstance().setPreferredInput(microphone.port)
  }

  /// Returns the current microphone input, if any.
  ///
  /// This function activates the audio session and then retrieves the first input from the current route.
  /// It converts the input to a `Microphone` object that contains the port name and type.
  ///
  /// - throws: An error if the audio session activation fails.
  /// - returns: A `Microphone` object representing the current input, or `nil` if there is no input.
  func currentMicrophone() async throws -> Microphone? {
    try activateSession()
    return AVAudioSession.sharedInstance().currentRoute.inputs.first.map(Microphone.init)
  }

  /// Updates the audio meters for the current recording session.
  ///
  /// - precondition: The `recorder` property must not be `nil`.
  /// - postcondition: The `recordingStateSubject` is updated with the current recording duration and power level.
  ///
  /// This function is called periodically by a timer when the recorder is active. It uses the `MainActor` to invalidate
  /// the timer if the recorder is `nil` or not recording. It also calls `updateMeters()` on the recorder and sends the
  /// latest values to the `recordingStateSubject`.
  private func updateMeters() async {
    guard let recorder else {
      await MainActor.run {
        timer?.invalidate()
      }
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

/// A type that represents an audio recorder with completion handlers for recording and encoding events.
///
/// The type conforms to the `AVAudioRecorderDelegate` protocol and provides two additional closures that are called
/// when the recording is finished or when an encoding error occurs. The closures are marked as `@Sendable` to allow
/// them to be executed concurrently.
///
/// To use this type, create an instance with the desired completion handlers and assign it as the delegate of an
/// `AVAudioRecorder` object. Then, start and stop the recording as usual. The delegate methods and the completion
/// handlers will be invoked accordingly.
private final class Delegate: NSObject, AVAudioRecorderDelegate, Sendable {
  /// A closure that is called when the recording is finished.
  ///
  /// - parameter successfully: A boolean value indicating whether the recording was completed successfully or not.
  /// - note: This closure is marked as `@Sendable` to allow it to be executed concurrently.
  let didFinishRecording: @Sendable (_ successfully: Bool) -> Void
  /// A closure that is called when an encoding error occurs.
  ///
  /// - parameter error: The error that occurred during encoding, or `nil` if no error occurred.
  /// - returns: Nothing.
  let encodeErrorDidOccur: @Sendable (Error?)
    -> Void

  /// Initializes a new instance of the class with the given completion handlers.
  ///
  /// - parameter didFinishRecording: A closure that is called when the recording is finished, with a boolean indicating
  /// whether the recording was successful or not.
  /// - parameter encodeErrorDidOccur: A closure that is called when an encoding error occurs, with an optional error
  /// object describing the failure.
  init(
    didFinishRecording: @escaping @Sendable (Bool) -> Void,
    encodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
  ) {
    self.didFinishRecording = didFinishRecording
    self.encodeErrorDidOccur = encodeErrorDidOccur
  }

  /// Tells the delegate that the audio recorder has finished recording.
  ///
  /// - parameter recorder: The audio recorder that finished recording.
  /// - parameter flag: A Boolean value that indicates whether the recording was successful.
  /// - note: This method is called when the audio recorder finishes recording due to reaching a time limit or being
  /// stopped explicitly. It is not called if the recording fails due to an audio encoding error.
  func audioRecorderDidFinishRecording(_: AVAudioRecorder, successfully flag: Bool) {
    didFinishRecording(flag)
  }

  /// Handles an encoding error that occurred while recording audio.
  ///
  /// - parameter _: The audio recorder that encountered the encoding error.
  /// - parameter error: The error that occurred, or nil if no error information is available.
  /// - calls: `encodeErrorDidOccur(_:)` to perform the actual error handling.
  func audioRecorderEncodeErrorDidOccur(_: AVAudioRecorder, error: Error?) {
    encodeErrorDidOccur(error)
  }
}
