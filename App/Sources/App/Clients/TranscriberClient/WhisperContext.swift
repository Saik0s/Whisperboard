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
  // FIXME: Make it a dictionary
  /// Temporarily store the swift callback to be able to call it from C callback
  private static var newSegmentCallback: ((String) -> Void)?

  private var context: OpaquePointer

  init(context: OpaquePointer) {
    self.context = context
  }

  deinit {
    whisper_free(context)
  }

  func fullTranscribe(samples: [Float], language: VoiceLanguage, isParallel: Bool, newSegmentCallback: @escaping (String) -> Void) throws {
    // TODO: Make it a dictionary
    WhisperContext.newSegmentCallback = newSegmentCallback

    let newSegmentCallback: @convention(c) (OpaquePointer?, OpaquePointer?, Int32, UnsafeMutableRawPointer?) -> Void = { context, _, _, _ in
      let segmentIndex = whisper_full_n_segments(context) - 1
      let segmentText = String(cString: whisper_full_get_segment_text(context, segmentIndex))
      log.verbose("New segment: \(segmentText) id: \(segmentIndex)")
      DispatchQueue.main.async {
        WhisperContext.newSegmentCallback?(segmentText)
      }

      // TODO: extract token data
      // // Get number of tokens in the specified segment.
      // WHISPER_API int whisper_full_n_tokens(struct whisper_context * ctx, int i_segment);
      //
      // // Get the token text of the specified token in the specified segment.
      // WHISPER_API const char * whisper_full_get_token_text(struct whisper_context * ctx, int i_segment, int i_token);
      // WHISPER_API whisper_token whisper_full_get_token_id (struct whisper_context * ctx, int i_segment, int i_token);
      //
      // // Get token data for the specified token in the specified segment.
      // // This contains probabilities, timestamps, etc.
      // WHISPER_API whisper_token_data whisper_full_get_token_data(struct whisper_context * ctx, int i_segment, int i_token);
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
    params.suppress_blank = true
    params.suppress_non_speech_tokens = true
    params.new_segment_callback = newSegmentCallback

    whisper_reset_timings(context)
    log.verbose("About to run whisper_full")
    try samples.withUnsafeBufferPointer { samples in
      if isParallel {
        if whisper_full_parallel(context, params, samples.baseAddress, Int32(samples.count), Int32(maxThreads)) != 0 {
          log.error("Failed to run the model in parallel")
          throw WhisperError.cantRunModel
        } else {
          whisper_print_timings(context)
        }
      } else {
        if whisper_full(context, params, samples.baseAddress, Int32(samples.count)) != 0 {
          log.error("Failed to run the model")
          throw WhisperError.cantRunModel
        } else {
          whisper_print_timings(context)
        }
      }
    }
  }

  func getTranscription() -> String {
    // TODO: Extract token data
    let segmentsCount = whisper_full_n_segments(context)

    return (0 ..< segmentsCount).map { i in
      String(cString: whisper_full_get_segment_text(context, i))
    }.joined(separator: " ")
  }

  func unloadContext() {
    whisper_free(context)
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
