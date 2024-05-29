import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import IdentifiedCollections
import os.log
import SwiftUI
import whisper
import WhisperKit

// MARK: - WhisperError

enum WhisperError: Error, LocalizedError {
  case cantLoadModel
  case noSamples

  var errorDescription: String? {
    switch self {
    case .cantLoadModel:
      "Can't load model"
    case .noSamples:
      "No samples"
    }
  }
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
  func fullTranscribe(audioFileURL: URL, params: TranscriptionParameters) -> AsyncThrowingStream<WhisperAction, Error>
  func cancel()
}

// MARK: - WhisperContext

final class WhisperContext: Identifiable, WhisperContextProtocol {
  private static var references: LockIsolated<IdentifiedArrayOf<WhisperContext>> = LockIsolated([])

  let id: Int
  private var isCancelled = false
  private let context: OpaquePointer
  private var continuation: LockIsolated<AsyncThrowingStream<WhisperAction, Error>.Continuation?> = .init(nil)

  init(id: Int = .random(in: Int.min ..< Int.max), modelPath: String, useGPU: Bool) throws {
    self.id = id
    var params = whisper_context_default_params()
    params.use_gpu = useGPU
    #if targetEnvironment(simulator)
      params.use_gpu = false
      print("Running on the simulator, using CPU")
    #endif
    guard let context = whisper_init_from_file_with_params(modelPath, params) else {
      logs.error("Couldn't load model at \(modelPath)")
      throw WhisperError.cantLoadModel
    }
    self.context = context
    Self.addReference(self)
  }

  deinit {
    Self.removeReference(self)
    whisper_free(context)
  }

  func fullTranscribe(audioFileURL: URL, params: TranscriptionParameters) -> AsyncThrowingStream<WhisperAction, Error> {
    isCancelled = false
    var fullParams = toWhisperParams(params)
    let idPointer = id.toPointer()
    fullParams.new_segment_callback_user_data = idPointer
    fullParams.progress_callback_user_data = idPointer
    fullParams.encoder_begin_callback_user_data = idPointer

    fullParams.new_segment_callback = { (ctx: OpaquePointer?, _: OpaquePointer?, newSegmentsCount: Int32, userData: UnsafeMutableRawPointer?) in
      guard let container = WhisperContext.getContainerFromIDPointer(userData) else {
        logs.error("Can't get container from ID pointer")
        return
      }

      let segmentCount = whisper_full_n_segments(ctx)
      let startIndex = segmentCount - newSegmentsCount

      for index in startIndex ..< segmentCount {
        let segment = getSegmentAt(context: ctx, index: index)
        container.newSegment(segment)
      }
    }
    fullParams.progress_callback = { (_: OpaquePointer?, _: OpaquePointer?, progress: Int32, userData: UnsafeMutableRawPointer?) in
      guard let container = WhisperContext.getContainerFromIDPointer(userData) else {
        logs.error("Can't get container from ID pointer")
        return
      }

      container.progress(Double(progress) / 100)
    }
    fullParams.encoder_begin_callback = { (_: OpaquePointer?, _: OpaquePointer?, userData: UnsafeMutableRawPointer?) in
      guard let container = WhisperContext.getContainerFromIDPointer(userData) else {
        logs.error("Can't get container from ID pointer")
        return true
      }

      return !container.isCancelled
    }

    let (stream, continuation) = AsyncThrowingStream.makeStream(of: WhisperAction.self)
    self.continuation.value?.finish()
    self.continuation.setValue(continuation)

    DispatchQueue.global(qos: .background).async { [self] in
      do {
        let samples = try convertAndDecodeWaveFile(audioFileURL)

        let freeMemory = freeMemoryAmount()
        logs.info("Free system memory available: \(freeMemory) bytes")

        // Calculate the size of samples in bytes
        let sampleSize = UInt64(MemoryLayout<Float>.size * samples.count)
        logs.info("Size of samples: \(sampleSize) bytes")

        // Calculate the memory that can be used for processing
        let usableMemory = freeMemory > sampleSize ? freeMemory - sampleSize : 0
        logs.info("Usable memory for processing: \(usableMemory) bytes")

        // Calculate the number of threads based on usable memory and sample size
        let numberOfThreads = usableMemory > 0 ? Int32(usableMemory / sampleSize) + 1 : 1
        logs.info("Calculated number of threads: \(numberOfThreads)")

        // Update parameters with the calculated number of threads if it is less than the current number of threads
        if numberOfThreads < fullParams.n_threads {
          logs.info("Adjusting number of threads from \(fullParams.n_threads) to \(numberOfThreads)")
          fullParams.n_threads = numberOfThreads
        }

        let code = samples.withUnsafeBufferPointer { [context] samples in
          whisper_full(context, fullParams, samples.baseAddress, Int32(samples.count))
        }

        logs.info("Whisper result code: \(code)")

        if isCancelled {
          doneCancelling()
        } else {
          let segments = extractSegments(context: context)
          finish(segments)
        }
      } catch {
        failed(error)
      }
    }

    continuation.onTermination = { [weak self] termination in
      switch termination {
      case .cancelled:
        self?.cancel()

      default:
        break
      }
    }

    return stream
  }

  func cancel() {
    Self.references.value[id: id]?.isCancelled = true
  }

  // MARK: - Private

  func doneCancelling() {
    continuation.withValue { cont in
      cont?.yield(.canceled)
      cont?.finish()
    }
  }

  func newSegment(_ segment: Segment) {
    _ = continuation.withValue { cont in
      cont?.yield(.newSegment(segment))
    }
  }

  func progress(_ progress: Double) {
    _ = continuation.withValue { cont in
      cont?.yield(.progress(progress))
    }
  }

  func finish(_ segments: [Segment]) {
    continuation.withValue { cont in
      cont?.yield(.finished(segments))
      cont?.finish()
    }
  }

  func failed(_ error: Error) {
    continuation.withValue { cont in
      cont?.finish(throwing: error)
    }
  }

  // MARK: - Private Static

  static func getAvailableLanguages() -> [VoiceLanguage] {
    let maxLangID = whisper_lang_max_id()
    return (0 ... maxLangID).map { id in
      let name = String(cString: whisper_lang_str(id))
      return VoiceLanguage(id: id, code: name)
    }
  }

  static func addReference(_ context: WhisperContext) {
    _ = references.withValue { $0.append(context) }
  }

  static func removeReference(_ context: WhisperContext) {
    _ = references.withValue { $0.remove(id: context.id) }
  }

  static func getContainerFromIDPointer(_ pointer: UnsafeMutableRawPointer?) -> WhisperContext? {
    guard let pointer else { return nil }
    let id = pointer.load(as: Int.self)
    return references.value[id: id]
  }
}

private extension Int {
  func toPointer() -> UnsafeMutableRawPointer {
    let pointer = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    pointer.pointee = self
    return UnsafeMutableRawPointer(pointer)
  }
}

private func convertAndDecodeWaveFile(_ url: URL) throws -> [Float] {
  let audioBuffer = try AudioProcessor.loadAudio(fromPath: url.path())
  let audioArray = AudioProcessor.convertBufferToArray(buffer: audioBuffer)
  return audioArray
}
