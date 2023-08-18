import AppDevUtils
import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import IdentifiedCollections
import os.log
import SwiftUI
import whisper


// MARK: - WhisperError

public enum WhisperError: Error {
  case cantLoadModel
  case cantRunModel
  case noSamples
  case referenceContainerNotFound
}


// MARK: - WhisperAction

public enum WhisperAction {
  case newSegment(Segment)
  case progress(Double)
  case error(Error)
  case canceled
  case finished([Segment])
}

public protocol WhisperContextProtocol {
  func fullTranscribe(samples: [Float], params: TranscriptionParameters) async throws -> AsyncChannel<WhisperAction>
  func cancel() -> Void

  static func createFrom(modelPath: String) async throws -> WhisperContextProtocol
  static func getAvailableLanguages() -> [VoiceLanguage]
}

// MARK: - WhisperContext

public final class WhisperContext: Identifiable, WhisperContextProtocol {
  static let referenceStore = ContextDataStore()

  public let id: Int = .random(in: 0 ..< Int.max)
  public private(set) var inProgress = false

  private var context: OpaquePointer

  init(context: OpaquePointer) {
    self.context = context
  }

  deinit {
    WhisperContext.referenceStore.removeReference(id: id)
    whisper_free(context)
  }

  public static func createFrom(modelPath: String) async throws -> WhisperContextProtocol {
    guard let context = whisper_init_from_file(modelPath) else {
      log.error("Couldn't load model at \(modelPath)")
      throw WhisperError.cantLoadModel
    }

    return WhisperContext(context: context)
  }

  public func fullTranscribe(samples: [Float], params: TranscriptionParameters) async throws -> AsyncChannel<WhisperAction> {
    guard !samples.isEmpty else {
      throw WhisperError.noSamples
    }
    inProgress = true

    let container = WhisperContext.referenceStore.createContainerWith(id: id)

    var fullParams = toWhisperParams(params)
    let idPointer = id.toPointer()
    fullParams.new_segment_callback_user_data = idPointer
    fullParams.progress_callback_user_data = idPointer
    fullParams.encoder_begin_callback_user_data = idPointer

    fullParams.new_segment_callback = { (ctx: OpaquePointer?, _: OpaquePointer?, newSegmentsCount: Int32, userData: UnsafeMutableRawPointer?) in
      guard let container = WhisperContext.referenceStore.getContainerFromIDPointer(userData) else { return }

      let segmentCount = whisper_full_n_segments(ctx)
      let startIndex = segmentCount - newSegmentsCount

      for index in startIndex ..< segmentCount {
        let segment = getSegmentAt(context: ctx, index: index)
        container.newSegment(segment)
      }
    }
    fullParams.progress_callback = { (_: OpaquePointer?, _: OpaquePointer?, progress: Int32, userData: UnsafeMutableRawPointer?) in
      guard let container = WhisperContext.referenceStore.getContainerFromIDPointer(userData) else { return }
      container.progress(Double(progress) / 100)
    }
    fullParams.encoder_begin_callback = { (_: OpaquePointer?, _: OpaquePointer?, userData: UnsafeMutableRawPointer?) in
      guard let container = WhisperContext.referenceStore.getContainerFromIDPointer(userData) else { return true }
      return !container.isCancelled
    }

    Task.detached(priority: .userInitiated) { [weak self, fullParams] in
      guard let self else { return }
      defer { self.inProgress = false }

      whisper_full(context, fullParams, samples, Int32(samples.count))

      let container = WhisperContext.referenceStore[id]
      let segments = extractSegments(context: context)

      if container?.isCancelled == true {
        container?.doneCancelling()
      }

      container?.finish(segments)
    }

    return container.actionChannel
  }

  public func cancel() {
    WhisperContext.referenceStore[id]?.isCancelled = true
  }

  public static func getAvailableLanguages() -> [VoiceLanguage] {
    let maxLangID = whisper_lang_max_id()
    return (0 ... maxLangID).map { id in
      let name = String(cString: whisper_lang_str(id))
      return VoiceLanguage(id: id, code: name)
    }
  }
}

private extension Int {
  func toPointer() -> UnsafeMutableRawPointer {
    let pointer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    pointer.pointee = self
    return UnsafeMutableRawPointer(pointer)
  }
}
