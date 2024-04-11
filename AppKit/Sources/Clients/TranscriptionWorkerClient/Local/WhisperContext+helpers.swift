
import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import IdentifiedCollections
import os.log
import SwiftUI
import whisper

func extractSegments(context: OpaquePointer?) -> [Segment] {
  let nSegments = whisper_full_n_segments(context)
  var segments: [Segment] = []

  for index in 0 ..< nSegments {
    let segment = getSegmentAt(context: context, index: index)
    segments.append(segment)
  }

  return segments
}

func getSegmentAt(context: OpaquePointer?, index: Int32) -> Segment {
  let segmentT0 = whisper_full_get_segment_t0(context, index) * 10 // convert to ms
  let segmentT1 = whisper_full_get_segment_t1(context, index) * 10 // convert to ms
  let segmentText = String(cString: whisper_full_get_segment_text(context, index))

  let nTokens: Int32 = whisper_full_n_tokens(context, index)
  var tokens: [Token] = []

  for tokenIndex in 0 ..< nTokens {
    let tokenText = String(cString: whisper_full_get_token_text(context, index, tokenIndex))
    let tokenId = whisper_full_get_token_id(context, index, tokenIndex)
    let tokenDataC = whisper_full_get_token_data(context, index, tokenIndex)

    let tokenData = TokenData(
      id: Int(tokenDataC.id),
      tid: Int(tokenDataC.tid),
      probability: tokenDataC.p,
      logProbability: tokenDataC.plog,
      timestampProbability: tokenDataC.pt,
      sumTimestampProbabilities: tokenDataC.ptsum,
      startTime: tokenDataC.t0,
      endTime: tokenDataC.t1,
      voiceLength: tokenDataC.vlen
    )

    let token = Token(id: tokenId, index: tokenIndex, text: tokenText, data: tokenData, speaker: nil)
    tokens.append(token)
  }

  return Segment(startTime: segmentT0, endTime: segmentT1, text: segmentText, tokens: tokens, speaker: nil)
}

// MARK: - WhisperContext + references

extension WhisperContext {
}
