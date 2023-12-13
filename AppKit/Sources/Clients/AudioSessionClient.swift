import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation

// MARK: - AudioSessionType

enum AudioSessionType {
  case playback
  case record
  case playAndRecord
}

// MARK: - AudioSessionClient

struct AudioSessionClient {
  var enable: @Sendable (_ type: AudioSessionType, _ updateActivation: Bool) throws -> Void
  var disable: @Sendable (_ type: AudioSessionType, _ updateActivation: Bool) throws -> Void
  var requestRecordPermission: @Sendable () async -> Bool
  var availableMicrophones: @Sendable () throws -> AsyncStream<[Microphone]>
  var currentMicrophone: @Sendable () -> Microphone?
  var selectMicrophone: @Sendable (Microphone) throws -> Void
}

extension DependencyValues {
  var audioSession: AudioSessionClient {
    get { self[AudioSessionClient.self] }
    set { self[AudioSessionClient.self] = newValue }
  }
}

// MARK: - AudioSessionClient + DependencyKey

extension AudioSessionClient: DependencyKey {
  static var liveValue: AudioSessionClient = {
    let isPlaybackActive = LockIsolated(false)
    let isRecordActive = LockIsolated(false)

    var session: AVAudioSession { AVAudioSession.sharedInstance() }

    var microphones: [Microphone] {
      session.availableInputs?.map(Microphone.init) ?? []
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
      @Dependency(\.settings) var settings: SettingsClient
      let shouldMixWithOthers = settings.getSettings().shouldMixWithOtherAudio
      let options: AVAudioSession.CategoryOptions = shouldMixWithOthers
        ? [.allowBluetooth, .mixWithOthers, .duckOthers, .defaultToSpeaker]
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

        if session.category != .playAndRecord
          || session.mode != mode
          || session.categoryOptions != options {
          try session.setCategory(.playAndRecord, mode: mode, options: options)
        }

        if updateActivation {
          let mic = getSelectedMicrophone()
          if mic?.isBuiltIn ?? false {
            var modifiedOptions = options
            modifiedOptions.remove(.allowBluetooth)
            modifiedOptions.insert(.allowBluetoothA2DP)
            try session.setCategory(.playAndRecord, mode: mode, options: modifiedOptions)
          }

          try session.setActive(true)
          try session.setPreferredInput(mic?.port)
        }
      },
      disable: { type, updateActivation in
        switch type {
        case .playback:
          isPlaybackActive.setValue(false)
        case .record:
          isRecordActive.setValue(false)
          if session.category != .playAndRecord
            || session.mode != mode
            || session.categoryOptions != options {
            try session.setCategory(.playAndRecord, mode: mode, options: options)
          }
        case .playAndRecord:
          isPlaybackActive.setValue(false)
          isRecordActive.setValue(false)
        }

        if updateActivation && (!isPlaybackActive.value && !isRecordActive.value) {
          try session.setActive(false)
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
        let updateStream = AsyncStream<[Microphone]>(
          NotificationCenter.default
            .notifications(named: AVAudioSession.routeChangeNotification)
            .map { _ -> [Microphone] in
              AVAudioSession.sharedInstance().availableInputs?.map(Microphone.init) ?? []
            }
        )

        try session.setCategory(.playAndRecord, mode: mode, options: options)

        return AsyncStream([Microphone].self) { continuation in
          continuation.yield(microphones)

          Task {
            for await microphones in updateStream {
              continuation.yield(microphones)
            }
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
