
import AsyncAlgorithms
import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import IdentifiedCollections
import os.log
import SwiftUI
import whisper

// MARK: - ContextDataStore

final class ContextDataStore {
  final class Container: Identifiable {
    let id: Int
    var isCancelled = false
    let actionChannel = AsyncChannel<WhisperAction>()

    init(id: Int) { self.id = id }
  }

  private var references: LockIsolated<IdentifiedArrayOf<Container>> = .init(.init())

  init() {}
}

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
  let segmentT0 = whisper_full_get_segment_t0(context, index)
  let segmentT1 = whisper_full_get_segment_t1(context, index)
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

  return Segment(index: Int(index), startTime: segmentT0, endTime: segmentT1, text: segmentText, tokens: tokens, speaker: nil)
}

extension ContextDataStore {
  func createContainerWith(id: Int) -> Container {
    removeReference(id: id)
    let container = Container(id: id)
    _ = references.withValue { $0.append(container) }
    return container
  }

  subscript(id: Int) -> Container? {
    references.value[id: id]
  }

  func removeReference(id: Int) {
    _ = references.withValue { $0.remove(id: id) }
  }

  func getContainerFromIDPointer(_ pointer: UnsafeMutableRawPointer?) -> Container? {
    guard let pointer else { return nil }
    let id = pointer.load(as: Int.self)
    return self[id]
  }
}

extension ContextDataStore.Container {
  func doneCancelling() {
    Task {
      await actionChannel.send(.canceled)
      actionChannel.finish()
    }
  }

  func newSegment(_ segment: Segment) {
    Task {
      await actionChannel.send(.newSegment(segment))
    }
  }

  func progress(_ progress: Double) {
    Task {
      await actionChannel.send(.progress(progress))
    }
  }

  func finish(_ segments: [Segment]) {
    Task {
      await actionChannel.send(.finished(segments))
      actionChannel.finish()
    }
  }
}
