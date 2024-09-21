import AVFoundation
import Combine
import Common
import ComposableArchitecture
import Dependencies
import Foundation

// MARK: - AudioSessionType

public enum AudioSessionType {
  case playback
  case record
  case playAndRecord
}

// MARK: - AudioSessionClient

public struct AudioSessionClient {
  public var enable: @Sendable (_ type: AudioSessionType, _ updateActivation: Bool) throws -> Void
  public var disable: @Sendable (_ type: AudioSessionType, _ updateActivation: Bool) throws -> Void
  public var requestRecordPermission: @Sendable () async -> Bool
  public var availableMicrophones: @Sendable () throws -> AsyncStream<[Microphone]>
  public var currentMicrophone: @Sendable () -> Microphone?
  public var selectMicrophone: @Sendable (Microphone) throws -> Void
}

public extension DependencyValues {
  var audioSession: AudioSessionClient {
    get { self[AudioSessionClient.self] }
    set { self[AudioSessionClient.self] = newValue }
  }
}

// MARK: - AudioSessionClient + DependencyKey

extension AudioSessionClient: DependencyKey {
  public static var liveValue: AudioSessionClient = {
    let isPlaybackActive = LockIsolated(false)
    let isRecordActive = LockIsolated(false)
    @Shared(.settings) var settings: Settings = .init()

    var session: AVAudioSession { AVAudioSession.sharedInstance() }

    var microphones: [Microphone] {
      (session.availableInputs?.map(Microphone.init) ?? []).sorted { mic1, mic2 in
        if mic1.isBuiltIn == mic2.isBuiltIn {
          return mic1.port.portName < mic2.port.portName
        }
        return !mic1.isBuiltIn && mic2.isBuiltIn
      }
    }

    @Sendable
    func getSelectedMicrophone() -> Microphone? {
      guard let id = UserDefaults.standard.selectedMicrophoneId else {
        return session.currentRoute.inputs.first.map(Microphone.init) ?? microphones.first
      }
      return microphones.first(where: { $0.id == id })
    }

    @Sendable
    func setSelectedMicrophone(_ microphone: Microphone) {
      UserDefaults.standard.selectedMicrophoneId = microphone.id
    }

    var mode: AVAudioSession.Mode {
      .default
    }

    var options: AVAudioSession.CategoryOptions {
      let shouldMixWithOthers = settings.shouldMixWithOtherAudio
      let options: AVAudioSession.CategoryOptions = shouldMixWithOthers
        ? [.allowBluetooth, .mixWithOthers, .defaultToSpeaker]
        : [.allowBluetooth, .defaultToSpeaker]
      return options
    }

    return AudioSessionClient(
      enable: { type, updateActivation in
        switch type {
        case .playback:
          isPlaybackActive.setValue(true)

        case .record:
          isRecordActive.setValue(true)

        case .playAndRecord:
          isPlaybackActive.setValue(true)
          isRecordActive.setValue(true)
        }

        var category: AVAudioSession.Category { isRecordActive.value ? .playAndRecord : .playback }

        if session.category != .playAndRecord
          || session.mode != mode
          || session.categoryOptions != options {
          try session.setCategory(category, mode: mode, options: options)
        }

        if updateActivation {
          let mic = getSelectedMicrophone()
          if mic?.isBuiltIn ?? false {
            var modifiedOptions = options
            modifiedOptions.remove(.allowBluetooth)
            modifiedOptions.insert(.allowBluetoothA2DP)
            try session.setCategory(category, mode: mode, options: modifiedOptions)
          }

          try session.setActive(true, options: .notifyOthersOnDeactivation)
          try session.setPreferredInput(mic?.port)
        }
      },
      disable: { type, updateActivation in
        var category: AVAudioSession.Category { isRecordActive.value ? .playAndRecord : .playback }
        switch type {
        case .playback:
          isPlaybackActive.setValue(false)

        case .record:
          isRecordActive.setValue(false)
          if session.category != .playAndRecord
            || session.mode != mode
            || session.categoryOptions != options {
            try session.setCategory(category, mode: mode, options: options)
          }

        case .playAndRecord:
          isPlaybackActive.setValue(false)
          isRecordActive.setValue(false)
        }

        if updateActivation && (!isPlaybackActive.value && !isRecordActive.value) {
          try session.setActive(false, options: .notifyOthersOnDeactivation)
        }
      },
      requestRecordPermission: {
        await withUnsafeContinuation { continuation in
          session.requestRecordPermission { granted in
            continuation.resume(returning: granted)
          }
        }
      },
      availableMicrophones: {
        AsyncStream([Microphone].self) { continuation in
          let task = Task(priority: .background) {
            let updateStream = NotificationCenter.default
              .publisher(for: AVAudioSession.routeChangeNotification)
              .map { _ -> [Microphone] in microphones }
              .removeDuplicates(by: { old, new in
                old.map(\.portName).sorted() != new.map(\.portName).sorted()
              })

            try session.setCategory(.playAndRecord, mode: mode, options: options)

            continuation.yield(microphones)

            for await microphones in updateStream.values {
              logs.debug("Microphones: \(microphones.map(\.port.portName).sorted())")
              continuation.yield(microphones)
            }
          }

          continuation.onTermination = { @Sendable _ in
            task.cancel()
          }
        }
      },
      currentMicrophone: {
        AVAudioSession.sharedInstance().currentRoute.inputs.first.map(Microphone.init) ?? getSelectedMicrophone()
      },
      selectMicrophone: { microphone in
        setSelectedMicrophone(microphone)
        if isRecordActive.value {
          try AVAudioSession.sharedInstance().setPreferredInput(microphone.port)
        }
      }
    )
  }()
}

private extension UserDefaults {
  var selectedMicrophoneId: String? {
    get { string(forKey: #function) }
    set { set(newValue, forKey: #function) }
  }
}
