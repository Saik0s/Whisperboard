//
// Created by Igor Tarasenko on 24/12/2022.
//

import SwiftUI
import AVFoundation

@MainActor
final class AppModel: ObservableObject {
  @Published var isLoadingModel = false
  @Published var isRecording = false
  @Published var isTranscribing = false
  @Published var recordings: [Recording] = []

  var canTranscribe: Bool { transcriber.isModelLoaded }

  private let recorder = Recorder()
  private let player = Player()
  private let transcriber = Transcriber()
  private let storage = Storage()

  private lazy var dateFormatter: DateFormatter = create {
    $0.dateFormat = "yyyy_MM_dd_HH_mm_ss"
  }

  init() {
    Task {
      isLoadingModel = true
      do {
        try await transcriber.loadModel()
      } catch {
        log(error)
      }
      isLoadingModel = false
    }
    reloadRecordings()
  }

  func toggleRecord() async {
    player.stopPlayback()

    if isRecording {
      await recorder.stopRecording()
      isRecording = false
    } else {
      guard await requestMicrophonePermission() else {
        log("Error getting microphone permissions")
        return
      }

      Task {
        isRecording = true
        do {
          let fileURL = try await self.recorder.startRecording(toOutputFile: newRecordingFileURL())
          isTranscribing = true
          let text = try await transcriber.transcribeAudio(fileURL)
          let recording = Recording(fileURL: fileURL, text: text)
          storage.recordings.append(recording)
          reloadRecordings()
        } catch {
          print(error.localizedDescription)
        }
        self.isRecording = false
        self.isTranscribing = false
      }
    }
  }

  private func requestMicrophonePermission() async -> Bool {
    await AVAudioSession.sharedInstance().requestRecordPermission()
  }

  private func newRecordingFileURL() throws -> URL {
    let filename = dateFormatter.string(from: Date()) + ".wav"
    let folderURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return folderURL.appendingPathComponent(filename)
  }

  private func reloadRecordings() {
    recordings = storage.recordings
  }
}

extension AVAudioSession {
  func requestRecordPermission() async -> Bool {
    await withCheckedContinuation { continuation in
      requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }
}