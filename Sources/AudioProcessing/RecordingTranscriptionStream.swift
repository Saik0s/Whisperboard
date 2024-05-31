import ComposableArchitecture
import Dependencies
import Foundation
import WhisperKit

// MARK: - LiveTranscriptionUpdate

public enum LiveTranscriptionUpdate {
  case transcription(TranscriptionStream.State)
  case recording(RecordingStream.State)
}

// MARK: - RecordingTranscriptionStream

@DependencyClient
public struct RecordingTranscriptionStream: Sendable {
  public var startLiveTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<LiveTranscriptionUpdate, Error> = { _ in .finished(throwing: nil) }

  public var startRecordingWithoutTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<RecordingStream.State, Error> = { _ in .finished(throwing: nil) }

  public var startFileTranscription: @Sendable (_ fileURL: URL) async throws
    -> AsyncThrowingStream<TranscriptionStream.State, Error> = { _ in .finished(throwing: nil) }

  public var stopRecording: @Sendable () async -> Void = {}
  public var pauseRecording: @Sendable () async -> Void = {}
  public var resumeRecording: @Sendable () async -> Void = {}
}

// MARK: DependencyKey

extension RecordingTranscriptionStream: DependencyKey {
  public static var liveValue: RecordingTranscriptionStream = {
    let container = RecordingTranscriptionStreamContainer()

    return RecordingTranscriptionStream(
      startLiveTranscription: { fileURL in
        container.startLiveTranscription(fileURL)
      },
      startRecordingWithoutTranscription: { fileURL in
        container.startRecordingWithoutTranscription(fileURL)
      },
      startFileTranscription: { fileURL in
        container.startFileTranscription(fileURL)
      },
      stopRecording: {
        container.stopRecording()
      },
      pauseRecording: {
        container.pauseRecording()
      },
      resumeRecording: {
        container.resumeRecording()
      }
    )
  }()
}

// MARK: - RecordingTranscriptionStreamContainer

private final class RecordingTranscriptionStreamContainer: DependencyKey {
  let audioProcessor: AudioProcessor = .init()
  var recordingStream: RecordingStream?
  var transcriptionStream: TranscriptionStream?

  func startLiveTranscription(_ fileURL: URL) async throws -> AsyncThrowingStream<LiveTranscriptionUpdate, Error> {
    AsyncThrowingStream { continuation in
      let recordingStream = RecordingStream(audioProcessor: audioProcessor) { state in
        continuation.yield(.recording(state))
      }

      let transcriptionStream = TranscriptionStream(audioProcessor: audioProcessor) { state in
        continuation.yield(.transcription(state))
      }

      self.recordingStream = recordingStream
      self.transcriptionStream = transcriptionStream

      let task = Task {
        do {
          async let recordingResult: Void = recordingStream.startRecording(at: fileURL)
          async let transcriptionResult: Void = transcriptionStream.startRealtimeLoop()

          try await recordingResult
          await transcriptionResult

          continuation.finish(throwing: nil)
        } catch {
          logs.error("Failed to start live transcription \(error)")
          continuation.finish(throwing: error)
        }

        self?.recordingStream = nil
        self?.transcriptionStream = nil
      }

      continuation.onTermination = { _ in
        recordingStream.stopRecording()
        transcriptionStream.stopRealtimeLoop()
        task.cancel()
        self?.recordingStream = nil
        self?.transcriptionStream = nil
      }
    }
  }

  func startRecordingWithoutTranscription(_ fileURL: URL) async throws -> AsyncThrowingStream<RecordingStream.State, Error> {
    AsyncThrowingStream { continuation in
      let recordingStream = RecordingStream(audioProcessor: audioProcessor) { state in
        continuation.yield(state)
      }

      self.recordingStream = recordingStream

      let task = Task { [weak self] in
        do {
          try await recordingStream.startRecording(at: fileURL)
          continuation.finish(throwing: nil)
        } catch {
          logs.error("Failed to start recording without transcription \(error)")
          continuation.finish(throwing: error)
        }

        self?.recordingStream = nil
      }

      continuation.onTermination = { _ in
        recordingStream.stopRecording()
        task.cancel()
        self.recordingStream = nil
      }
    }
  }

  func startFileTranscription(_ fileURL: URL) async throws -> AsyncThrowingStream<TranscriptionStream.State, Error> {
    AsyncThrowingStream { continuation in
      let transcriptionStream = TranscriptionStream(audioProcessor: audioProcessor) { state in
        continuation.yield(state)
      }

      self.transcriptionStream = transcriptionStream

      let task = Task { [weak self, audioProcessor] in
        do {
          let audioBuffer = try await audioProcessor.loadAudio(at: [fileURL.path()]).first.require().get()
          audioProcessor.processBuffer(audioBuffer)
          try await transcriptionStream.startRealtimeLoop(shouldStopWhenNoSamplesLeft: true)
          continuation.finish(throwing: nil)
        } catch {
          logs.error("Failed to start file transcription \(error)")
          continuation.finish(throwing: error)
        }

        self?.transcriptionStream = nil
      }

      continuation.onTermination = { _ in
        transcriptionStream.stopRealtimeLoop()
        task.cancel()
        self.transcriptionStream = nil
      }
    }
  }

  func stopRecording() {
    recordingStream?.stopRecording()
    transcriptionStream?.stopRealtimeLoop()
  }

  func pauseRecording() {
    recordingStream?.pauseRecording()
  }

  func resumeRecording() {
    recordingStream?.resumeRecording()
  }
}
