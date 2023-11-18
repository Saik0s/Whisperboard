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
        ? [.allowBluetooth, .defaultToSpeaker, .mixWithOthers, .duckOthers]
        : [.allowBluetooth, .defaultToSpeaker]
      return options
    }

    return AudioSessionClient(
      enable: { type, updateActivation in
        switch type {
        case .playback:
          isPlaybackActive.setValue(true)
          if AVAudioSession.sharedInstance().category != .playAndRecord {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: mode, options: options)
          }
        case .record:
          isRecordActive.setValue(true)
          if isPlaybackActive.value {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: mode, options: options)
          } else {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: mode, options: options)
          }
        case .playAndRecord:
          isPlaybackActive.setValue(true)
          isRecordActive.setValue(true)
          if AVAudioSession.sharedInstance().category != .playAndRecord {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: mode, options: options)
          }
        }

        if updateActivation {
          try AVAudioSession.sharedInstance().setActive(true)
        }
      },
      disable: { type, updateActivation in
        switch type {
        case .playback:
          isPlaybackActive.setValue(false)
          if AVAudioSession.sharedInstance().category == .playAndRecord {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: mode, options: options)
          }
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
