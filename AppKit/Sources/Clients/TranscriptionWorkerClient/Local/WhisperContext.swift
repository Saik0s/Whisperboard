
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

enum WhisperError: Error {
  case cantLoadModel
  case noSamples
}

// MARK: - WhisperAction

enum WhisperAction {
  case newSegment(Segment)
  case progress(Double)
  case error(Error)
  case canceled
  case finished([Segment])
}

// MARK: - WhisperContextProtocol

protocol WhisperContextProtocol {
  func fullTranscribe(samples: [Float], params: TranscriptionParameters) async throws -> AsyncChannel<WhisperAction>
  func cancel() -> Void
}

// MARK: - WhisperContext

final class WhisperContext: Identifiable, WhisperContextProtocol {
  static let referenceStore = ContextDataStore()

  let id: Int = .random(in: 0 ..< Int.max)
  private(set) var inProgress = false

  private var context: OpaquePointer

  init(context: OpaquePointer) {
    self.context = context
  }

  deinit {
    WhisperContext.referenceStore.removeReference(id: id)
    whisper_free(context)
  }

  static func createFrom(modelPath: String) async throws -> WhisperContextProtocol {
    let params = whisper_context_params(use_gpu: true)
    guard let context = whisper_init_from_file_with_params(modelPath, params) else {
      log.error("Couldn't load model at \(modelPath)")
      throw WhisperError.cantLoadModel
    }

    return WhisperContext(context: context)
  }

  func fullTranscribe(samples: [Float], params: TranscriptionParameters) async throws -> AsyncChannel<WhisperAction> {
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

      // Not the best solution, but it works
      try? await Task.sleep(for: .seconds(0.3))

      if container?.isCancelled == true {
        container?.doneCancelling()
      } else {
        container?.finish(segments)
      }
    }

    return container.actionChannel
  }

  func cancel() {
    WhisperContext.referenceStore[id]?.isCancelled = true
  }

  static func getAvailableLanguages() -> [VoiceLanguage] {
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
