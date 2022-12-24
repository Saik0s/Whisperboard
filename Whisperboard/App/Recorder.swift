//
// Created by Igor Tarasenko on 24/12/2022.
//

import Foundation
import AVFoundation

actor Recorder: NSObject, AVAudioRecorderDelegate {
  enum RecorderError: Error {
    case couldNotStartRecording
    case finishedUnsuccessfully
    case stopped
  }

  private var recorder: AVAudioRecorder?
  private var onFinish: ((Result<URL, Error>) -> Void)?

  func startRecording(toOutputFile url: URL) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      startRecording(toOutputFile: url) { result in
        switch result {
        case .success(let outputFile):
          continuation.resume(returning: outputFile)
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func startRecording(toOutputFile url: URL, onFinish: @escaping (Result<URL, Error>) -> Void) {
    self.onFinish = onFinish

    do {
      let recordSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
      ]
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default)
      let recorder = try AVAudioRecorder(url: url, settings: recordSettings)
      recorder.delegate = self
      if recorder.record() == false {
        log("Could not start recording")
        throw RecorderError.couldNotStartRecording
      }
      self.recorder = recorder
    } catch {
      onFinish(.failure(error))
    }
  }

  func stopRecording() {
    recorder?.stop()
    recorder = nil
  }

  // MARK: AVAudioRecorderDelegate

  nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    if let error {
      log(error)
      Task {
        await onFinish?(.failure(error))
      }
    }
  }

  nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    Task {
      if flag {
        await onFinish?(.success(recorder.url))
      } else {
        await onFinish?(.failure(RecorderError.finishedUnsuccessfully))
      }
    }
  }
}
