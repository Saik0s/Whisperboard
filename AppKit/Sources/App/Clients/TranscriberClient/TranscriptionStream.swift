import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import RecognitionKit

// MARK: - TranscriberError

/// An enumeration of possible errors that can occur when using a transcriber.
///
/// A transcriber is an object that converts speech to text using a trained model.
///
/// - couldNotLocateModel: The model file could not be found in the specified location.
/// - modelNotLoaded: The model file could not be loaded into memory or initialized properly.
/// - notEnoughMemory: There is not enough memory available to load the model or perform the transcription. The
/// associated values are the available and required memory in bytes.
/// - cancelled: The transcription operation was cancelled by the user or the system.
///
/// This enumeration conforms to the Error and CustomStringConvertible protocols, which means it can be thrown as an
/// error and printed as a string.
enum TranscriberError: Error, CustomStringConvertible, Hashable {
  case couldNotLocateModel
  case modelNotLoaded
  case notEnoughMemory(available: UInt64, required: UInt64)
  case cancelled
}

// MARK: - TranscriptionState

public struct TranscriptionState: Hashable {
  enum Progress: Hashable {
    case starting
    case loadingModel
    case transcribing([WhisperTranscriptionSegment])
    case finished(String)
    case error(TranscriberError)
  }

  var progress: Progress = .starting
  var segments: [WhisperTranscriptionSegment] {
    get {
      if case let .transcribing(segments) = progress {
        return segments
      } else {
        return []
      }
    }
    set {
      progress = .transcribing(newValue)
    }
  }
  var finalText: String {
    get {
      if case let .finished(text) = progress {
        return text
      } else {
        return ""
      }
    }
    set {
      progress = .finished(newValue)
    }
  }
  var error: TranscriberError? {
    get {
      if case let .error(error) = progress {
        return error
      } else {
        return nil
      }
    }
    set {
      if let error = newValue {
        progress = .error(error)
      }
    }
  }
}

// MARK: - TranscriptionsStream

protocol TranscriptionsStream: AnyObject {
  func updateState(fileName: FileName, state: TranscriptionState?)
  func updateStateKey<Value>(fileName: FileName, keyPath: WritableKeyPath<TranscriptionState, Value>, value: Value)
  var asyncStream: AsyncStream<[FileName: TranscriptionState]> { get }
  func state(for: FileName) -> TranscriptionState?
}

// MARK: - TranscriptionsStreamImpl

final class TranscriptionsStreamImpl: TranscriptionsStream {
  @Published private var _states: [FileName: TranscriptionState] = [:]

  func updateState(fileName: FileName, state: TranscriptionState?) {
    _states[fileName] = state
  }

  func updateStateKey<Value>(fileName: FileName, keyPath: WritableKeyPath<TranscriptionState, Value>, value: Value) {
    if _states[fileName] == nil {
      _states[fileName] = TranscriptionState()
    }
    _states[fileName]?[keyPath: keyPath] = value
  }


  var asyncStream: AsyncStream<[FileName: TranscriptionState]> {
    $_states.asAsyncStream()
  }

  func state(for fileName: FileName) -> TranscriptionState? {
    _states[fileName]
  }
}

// MARK: - TranscriptionsStreamKey

private enum TranscriptionsStreamKey: DependencyKey {
  static let liveValue: TranscriptionsStream = TranscriptionsStreamImpl()
}

extension DependencyValues {
  var transcriptionsStream: any TranscriptionsStream {
    get { self[TranscriptionsStreamKey.self] }
    set { self[TranscriptionsStreamKey.self] = newValue }
  }
}

extension TranscriberError {
  /// Returns a localized description of the error.
  ///
  /// - returns: A `String` that describes the error in a human-readable format.
  var localizedDescription: String {
    switch self {
    case .couldNotLocateModel:
      return "Could not locate model"
    case .modelNotLoaded:
      return "Model not loaded"
    case let .notEnoughMemory(available, required):
      return "Not enough memory. Available: \(bytesToReadableString(bytes: available)), required: \(bytesToReadableString(bytes: required))"
    case .cancelled:
      return "Cancelled"
    }
  }

  /// Returns the localized description of the error.
  ///
  /// - returns: A `String` representing the error message in the current locale.
  var description: String {
    localizedDescription
  }
}

extension TranscriptionState {
  /// Returns a Boolean value indicating whether the transcription is in progress.
  ///
  /// - returns: `true` if the state is `.starting`, `.loadingModel`, or `.transcribing`; otherwise, `false`.
  var isTranscribing: Bool {
    switch progress {
    case .starting, .loadingModel, .transcribing:
      return true
    default:
      return false
    }
  }
}
