import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation

// MARK: - AudioSessionType

public enum AudioSessionType {
  case playback
  case record
  case playAndRecord

  var category: AVAudioSession.Category {
    switch self {
    case .playback:
      return .playback
    case .record:
      return .record
    case .playAndRecord:
      return .playAndRecord
    }
  }
}

// MARK: - AudioSessionClient

public struct AudioSessionClient {
  var enable: @Sendable (_ type: AudioSessionType, _ updateActivation: Bool) throws -> Void
  var disable: @Sendable (_ type: AudioSessionType, _ updateActivation: Bool) throws -> Void
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

    return AudioSessionClient(
      enable: { type, updateActivation in
        switch type {
        case .playback:
          isPlaybackActive.setValue(true)
          if AVAudioSession.sharedInstance().category != .playAndRecord {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
          }
        case .record:
          isRecordActive.setValue(true)
          if isPlaybackActive.value {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
          } else {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default, options: [.allowBluetooth])
          }
        case .playAndRecord:
          isPlaybackActive.setValue(true)
          isRecordActive.setValue(true)
          if AVAudioSession.sharedInstance().category != .playAndRecord {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
          }
        }

        if updateActivation && (isPlaybackActive.value || isRecordActive.value) {
          try AVAudioSession.sharedInstance().setActive(true)
        }
      },
      disable: { type, updateActivation in
        switch type {
        case .playback:
          isPlaybackActive.setValue(false)
          if AVAudioSession.sharedInstance().category == .playAndRecord {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default, options: [.allowBluetooth])
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
