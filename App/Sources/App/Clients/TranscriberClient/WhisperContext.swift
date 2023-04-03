import AppDevUtils
import Foundation
import whisper

// MARK: - WhisperError

enum WhisperError: Error {
  case cantLoadModel
  case cantRunModel
}

// MARK: - WhisperContext

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
  /// Temporarily store the swift callback to be able to call it from C callback
  private static var newSegmentCallback: ((String) -> Void)?

  private var context: OpaquePointer

  init(context: OpaquePointer) {
    self.context = context
  }

  deinit {
    whisper_free(context)
  }

  func fullTranscribe(samples: [Float], language: VoiceLanguage, newSegmentCallback: @escaping (String) -> Void) throws {
    WhisperContext.newSegmentCallback = newSegmentCallback

    let newSegmentCallback: @convention(c) (OpaquePointer?, Int32, UnsafeMutableRawPointer?) -> Void = { context, _, _ in
      let segmentText = String(cString: whisper_full_get_segment_text(context, whisper_full_n_segments(context) - 1))
      WhisperContext.newSegmentCallback?(segmentText)
    }

    // Leave 2 processors free (i.e. the high-efficiency cores).
    let maxThreads = max(1, min(8, cpuCount() - 2))
    log.verbose("Selecting \(maxThreads) threads")

    var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
    params.print_realtime = false
    params.print_progress = false
    params.print_timestamps = false
    params.print_special = false
    params.translate = false
    params.language = language.isAuto ? nil : whisper_lang_str(language.id)
    params.n_threads = Int32(maxThreads)
    params.offset_ms = 0
    params.no_context = true
    params.single_segment = false
    params.new_segment_callback = newSegmentCallback

    whisper_reset_timings(context)
    log.verbose("About to run whisper_full")
    try samples.withUnsafeBufferPointer { samples in
      if whisper_full(context, params, samples.baseAddress, Int32(samples.count)) != 0 {
        log.error("Failed to run the model")
        throw WhisperError.cantRunModel
      } else {
        whisper_print_timings(context)
      }
    }
  }

  func getTranscription() -> String {
    let segmentsCount = whisper_full_n_segments(context)

    return (0 ..< segmentsCount).map { i in
      String(cString: whisper_full_get_segment_text(context, i))
    }.joined(separator: " ")
  }

  static func createContext(path: String) throws -> WhisperContext {
    let context = whisper_init_from_file(path)
    if let context {
      return WhisperContext(context: context)
    } else {
      log.verbose("Couldn't load model at \(path)")
      throw WhisperError.cantLoadModel
    }
  }

  static func getAvailableLanguages() -> [VoiceLanguage] {
    let maxLangID = whisper_lang_max_id()

    return (0 ... maxLangID).map { id in
      let name = String(cString: whisper_lang_str(id))
      return VoiceLanguage(id: id, code: name)
    }
  }
}

private func cpuCount() -> Int {
  ProcessInfo.processInfo.processorCount
}
