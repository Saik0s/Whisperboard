import Foundation
import whisper

func toWhisperParams(_ params: TranscriptionParameters) -> whisper_full_params {
  var whisperParams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
  whisperParams.print_realtime = params.printRealtimeResults
  whisperParams.print_progress = params.printProgressInfo
  whisperParams.print_timestamps = params.printTimestamps
  whisperParams.print_special = params.printSpecialTokens
  whisperParams.translate = params.shouldTranslate
  whisperParams.language = params.language.isAuto ? nil : whisper_lang_str(params.language.id)
  whisperParams.n_threads = Int32(params.threadCount)
  whisperParams.offset_ms = Int32(params.offsetMilliseconds)
  whisperParams.no_context = params.noContext
  whisperParams.single_segment = params.singleSegmentOutput
  whisperParams.suppress_blank = params.suppressBlank
  whisperParams.suppress_non_speech_tokens = params.suppressNonSpeechTokens
  whisperParams.initial_prompt = params.initialPrompt?.copyAsCString()
  whisperParams.audio_ctx = Int32(params.audioContextSize)
  whisperParams.token_timestamps = params.enableTokenTimestamps
  whisperParams.thold_pt = params.timestampTokenProbabilityThreshold
  whisperParams.thold_ptsum = params.timestampTokenSumProbabilityThreshold
  whisperParams.max_len = Int32(params.maxSegmentLength)
  whisperParams.split_on_word = params.splitOnWord
  whisperParams.max_tokens = Int32(params.maxTokensPerSegment)
  whisperParams.speed_up = params.speedUpAudio
  whisperParams.temperature = params.temperature
  whisperParams.max_initial_ts = params.maxInitialTimestamp
  whisperParams.length_penalty = params.lengthPenalty
  whisperParams.temperature_inc = params.temperatureIncrease
  whisperParams.entropy_thold = params.entropyThreshold
  whisperParams.logprob_thold = params.logProbabilityThreshold
  whisperParams.no_speech_thold = params.noSpeechThreshold
  whisperParams.greedy.best_of = Int32(params.greedyBestOf)
  return whisperParams
}

private extension String {
  func copyAsCString() -> UnsafePointer<Int8> {
    self.withCString { cString in UnsafePointer(strdup(cString)) }
  }
}
