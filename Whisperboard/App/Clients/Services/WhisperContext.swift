import Foundation
import whisper

// MARK: - WhisperError

enum WhisperError: Error {
  case couldNotInitializeContext
}

// MARK: - WhisperContext

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
  private var context: OpaquePointer

  init(context: OpaquePointer) {
    self.context = context
  }

  deinit {
    whisper_free(context)
  }

  func fullTranscribe(samples: [Float]) {
    // Leave 2 processors free (i.e. the high-efficiency cores).
    let maxThreads = max(1, min(8, cpuCount() - 2))
    log("Selecting \(maxThreads) threads")
    var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
    "".withCString { language in
      // Adapted from whisper.objc
      params.print_realtime = true
      params.print_progress = false
      params.print_timestamps = true
      params.print_special = false
      params.translate = false
      params.language = language
      params.n_threads = Int32(maxThreads)
      params.offset_ms = 0
      params.no_context = true
      params.single_segment = false
      params.new_segment_callback = { context, _, _ in
        log(String(cString: whisper_full_get_segment_text(context, whisper_full_n_segments(context) - 1)))
      }

      whisper_reset_timings(context)
      log("About to run whisper_full")
      samples.withUnsafeBufferPointer { samples in
        if whisper_full(context, params, samples.baseAddress, Int32(samples.count)) != 0 {
          log("Failed to run the model")
        } else {
          whisper_print_timings(context)
        }
      }
    }
  }

  func getTranscription() -> String {
    var transcription = ""
    for i in 0 ..< whisper_full_n_segments(context) {
      transcription += String(cString: whisper_full_get_segment_text(context, i))
    }
    return transcription
  }

  static func createContext(path: String) throws -> WhisperContext {
    let context = whisper_init_from_file(path)
    if let context {
      return WhisperContext(context: context)
    } else {
      log("Couldn't load model at \(path)")
      throw WhisperError.couldNotInitializeContext
    }
  }
}

private func cpuCount() -> Int {
  ProcessInfo.processInfo.processorCount
}
