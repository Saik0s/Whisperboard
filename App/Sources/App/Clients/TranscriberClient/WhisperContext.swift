import AppDevUtils
import Foundation
import whisper

// MARK: - WhisperTranscriptionSegment

struct WhisperTranscriptionSegment: Hashable {
  var index: Int32
  var text: String
}

// MARK: - WhisperError

enum WhisperError: Error {
  case cantLoadModel
  case cantRunModel
}

// MARK: - WhisperContext

actor WhisperContext {
  private static var newSegmentCallback: ((WhisperTranscriptionSegment) -> Void)?
  private var context: OpaquePointer

  init(context: OpaquePointer) {
    self.context = context
  }

  deinit {
    whisper_free(context)
  }

  func fullTranscribe(
    samples: [Float],
    language: VoiceLanguage,
    isParallel: Bool,
    newSegmentCallback: @escaping (WhisperTranscriptionSegment) -> Void
  ) throws {
    WhisperContext.newSegmentCallback = newSegmentCallback
    let newSegmentCallback = createNewSegmentCallback()
    let params = createWhisperParams(language: language, isParallel: isParallel, newSegmentCallback: newSegmentCallback)
    try runWhisperFull(samples: samples, isParallel: isParallel, params: params)
    WhisperContext.newSegmentCallback = nil
  }

  func getTranscription() async throws -> String {
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

  private func createNewSegmentCallback() -> (@convention(c) (OpaquePointer?, OpaquePointer?, Int32, UnsafeMutableRawPointer?) -> Void) {
    return { context, _, _, _ in
      let segmentIndex = whisper_full_n_segments(context) - 1
      let segmentText = String(cString: whisper_full_get_segment_text(context, segmentIndex))
      let segment = WhisperTranscriptionSegment(index: segmentIndex, text: segmentText)
      DispatchQueue.main.async {
        log.verbose("New segment: \(segmentText) id: \(segmentIndex)")
        WhisperContext.newSegmentCallback?(segment)
      }
    }
  }

  private func createWhisperParams(language: VoiceLanguage, isParallel: Bool, newSegmentCallback: @escaping (@convention(c) (OpaquePointer?, OpaquePointer?, Int32, UnsafeMutableRawPointer?) -> Void)) -> whisper_full_params {
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
    let text = "Dictating my notes."
    params.initial_prompt = text.cString(using: .utf8)?.withUnsafeBufferPointer {
      UnsafePointer($0.baseAddress)
    }

    return params
  }

  private func runWhisperFull(samples: [Float], isParallel: Bool, params: whisper_full_params) throws {
    whisper_reset_timings(context)
    log.verbose("About to run whisper_full")
    try samples.withUnsafeBufferPointer { samples in
      if isParallel {
        if whisper_full_parallel(context, params, samples.baseAddress, Int32(samples.count), Int32(params.n_threads)) != 0 {
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

  private func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
  }
}
