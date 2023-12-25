
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
  func fullTranscribe(audioFileURL: URL, params: TranscriptionParameters) async throws -> AsyncChannel<WhisperAction>
  func cancel() async -> Void
}

// MARK: - WhisperContext

actor WhisperContext: Identifiable, WhisperContextProtocol {
  static let referenceStore = ContextDataStore()

  let id: Int = .random(in: 0 ..< Int.max)

  private var context: OpaquePointer

  init(context: OpaquePointer) {
    self.context = context
  }

  deinit {
    WhisperContext.referenceStore.removeReference(id: id)
    whisper_free(context)
  }

  static func createFrom(modelPath: String) async throws -> WhisperContextProtocol {
    var params = whisper_context_default_params()
    #if targetEnvironment(simulator)
      params.use_gpu = false
      print("Running on the simulator, using CPU")
    #endif
    guard let context = whisper_init_from_file_with_params(modelPath, params) else {
      log.error("Couldn't load model at \(modelPath)")
      throw WhisperError.cantLoadModel
    }

    return WhisperContext(context: context)
  }

  func fullTranscribe(audioFileURL: URL, params: TranscriptionParameters) async throws -> AsyncChannel<WhisperAction> {
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

    Task.detached(priority: .userInitiated) { [container, context, fullParams] in
      do {
        let samples = try decodeWaveFile(audioFileURL)

        let freeMemory = freeMemoryAmount()
        log.info("Free system memory available: \(freeMemory) bytes")

        // Calculate the size of samples in bytes
        let sampleSize = UInt64(MemoryLayout<Float>.size * samples.count)
        log.info("Size of samples: \(sampleSize) bytes")

        // Calculate the memory that can be used for processing
        let usableMemory = freeMemory > sampleSize ? freeMemory - sampleSize : 0
        log.info("Usable memory for processing: \(usableMemory) bytes")

        // Calculate the number of threads based on usable memory and sample size
        let numberOfThreads = usableMemory > 0 ? Int32(usableMemory / sampleSize) + 1 : 1
        log.info("Calculated number of threads: \(numberOfThreads)")

        // Update parameters with the calculated number of threads if it is less than the current number of threads
        var fullParams = fullParams
        if numberOfThreads < fullParams.n_threads {
          log.info("Adjusting number of threads from \(fullParams.n_threads) to \(numberOfThreads)")
          fullParams.n_threads = numberOfThreads
        }

        let code = samples.withUnsafeBufferPointer { [context] samples in
          whisper_full(context, fullParams, samples.baseAddress, Int32(samples.count))
        }

        print("Whisper result code: \(code)")

        let segments = extractSegments(context: context)

        // Not the best solution, but it works
        try? await Task.sleep(for: .seconds(0.3))

        if container.isCancelled == true {
          container.doneCancelling()
        } else {
          container.finish(segments)
        }
      } catch {
        container.failed(error)
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

private func decodeWaveFile(_ url: URL) throws -> [Float] {
  let data = try Data(contentsOf: url)
  let floats = stride(from: 44, to: data.count, by: 2).map {
    data[$0 ..< $0 + 2].withUnsafeBytes {
      let short = Int16(littleEndian: $0.load(as: Int16.self))
      return max(-1.0, min(Float(short) / 32767.0, 1.0))
    }
  }
  return floats
}
