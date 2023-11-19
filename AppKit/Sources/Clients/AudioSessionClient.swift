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

    var mode: AVAudioSession.Mode {
      .voiceChat
    }
    var options: AVAudioSession.CategoryOptions {
      @Dependency(\.settings) var settings: SettingsClient
      let shouldMixWithOthers = settings.getSettings().shouldMixWithOtherAudio
      let options: AVAudioSession.CategoryOptions = shouldMixWithOthers
        ? [.allowBluetooth, .mixWithOthers, .duckOthers]
        : [.allowBluetooth]
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

        if AVAudioSession.sharedInstance().category != .playAndRecord
          || AVAudioSession.sharedInstance().mode != mode
          || AVAudioSession.sharedInstance().categoryOptions != options {
          try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: mode, options: options)
        }

        if updateActivation {
          try AVAudioSession.sharedInstance().setActive(true)
        }
      },
      disable: { type, updateActivation in
        switch type {
        case .playback:
          isPlaybackActive.setValue(false)
        case .record:
          isRecordActive.setValue(false)
        case .playAndRecord:
          isPlaybackActive.setValue(false)
          isRecordActive.setValue(false)
        }

        if updateActivation && (!isPlaybackActive.value && !isRecordActive.value) {
          try AVAudioSession.sharedInstance().setActive(false)
        }
      }
    )
  }()
}
