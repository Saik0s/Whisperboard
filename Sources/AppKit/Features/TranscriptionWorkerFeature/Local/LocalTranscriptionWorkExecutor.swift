import AsyncAlgorithms
import Common
import Dependencies
import Foundation
import WhisperKit

// MARK: - LocalTranscriptionError

enum LocalTranscriptionError: Error, LocalizedError {
  case notEnoughMemory(available: UInt64, required: UInt64)

  var errorDescription: String? {
    switch self {
    case let .notEnoughMemory(available, required):
      "Not enough memory to transcribe file. Available: \(bytesToReadableString(bytes: available)), required: \(bytesToReadableString(bytes: required))"
    }
  }
}

// MARK: - LocalTranscriptionWorkExecutor

final class LocalTranscriptionWorkExecutor: TranscriptionWorkExecutor {
  var currentTaskID: TranscriptionTask.ID?

  init() {}

  func process(task: TranscriptionTaskEnvelope) async {
    let taskId = await MainActor.run { task.id }
    logs.debug("Starting transcription process for task ID: \(taskId)")
    currentTaskID = taskId
    defer {
      logs.debug("Ending transcription process for task ID: \(taskId)")
      currentTaskID = nil
    }

    DispatchQueue.main.async {
      if task.recording.transcription?.id != taskId {
        logs.debug("Initializing new transcription for task ID: \(taskId)")
        task.recording.transcription = Transcription(id: taskId, fileName: task.fileName, parameters: task.parameters, model: task.modelType)
      }
    }

    do {
      DispatchQueue.main.async {
        logs.debug("Setting transcription status to loading for task ID: \(taskId)")
        task.recording.transcription?.status = .loading
      }

      let model = await task.modelType

      // MARK: Load model

      let computeOptions = ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine)
      let whisperKit = try await WhisperKit(model: model, computeOptions: computeOptions, load: true)

      logs.debug("Model (\(model)) loaded for task ID \(taskId)")

      DispatchQueue.main.async {
        logs.debug("Setting transcription status to progress for task ID: \(taskId)")
        task.recording.transcription?.status = .progress(task.progress, text: "")
      }

      // MARK: Load audio file

      let fileURL = await task.recording.fileURL
      logs.debug("File URL for task ID \(taskId): \(fileURL)")

      let audioBuffer = try AudioProcessor.loadAudio(fromPath: fileURL.path())
      let audioArray = AudioProcessor.convertBufferToArray(buffer: audioBuffer)

      var results: [TranscriptionResult?] = []
      var prevResult: TranscriptionResult?
      var lastAgreedSeconds: Float = 0.0
      let agreementCountNeeded = 2
      var hypothesisWords: [WordTiming] = []
      var prevWords: [WordTiming] = []
      var lastAgreedWords: [WordTiming] = []
      var confirmedWords: [WordTiming] = []

      let options = DecodingOptions(task: .transcribe, skipSpecialTokens: true, wordTimestamps: true, suppressBlank: true, concurrentWorkerCount: 2)

      //      for seekSample in stride(from: 16000, to: audioArray.count, by: 16000) {
      //      let endSample = min(seekSample + 16000, audioArray.count)
      //      let simulatedStreamingAudio = Array(audioArray[..<endSample])
      if true {
        //        let seekSample = 0
        //        let endSample = audioArray.count
        let simulatedStreamingAudio = audioArray

        var streamOptions = options
        streamOptions.clipTimestamps = [lastAgreedSeconds]
        let lastAgreedTokens = lastAgreedWords.flatMap(\.tokens)
        streamOptions.prefixTokens = lastAgreedTokens
        do {
          let result: TranscriptionResult? = try await whisperKit.transcribe(
            audioArray: simulatedStreamingAudio,
            decodeOptions: streamOptions,
            callback: { progress in
              DispatchQueue.main.async {
                task.recording.transcription?.status = .progress(whisperKit.progress.fractionCompleted, text: progress.text)
              }
              return true
            }
          ).firstgaq
          var skipAppend = false
          if let result, let _ = result.segments.first?.words {
            hypothesisWords = result.allWords.filter { $0.start >= lastAgreedSeconds }

            if let prevResult {
              prevWords = prevResult.allWords.filter { $0.start >= lastAgreedSeconds }
              let commonPrefix = findLongestCommonPrefix(prevWords, hypothesisWords)

              if commonPrefix.count >= agreementCountNeeded {
                lastAgreedWords = commonPrefix.suffix(agreementCountNeeded)
                lastAgreedSeconds = lastAgreedWords.first!.start

                confirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - agreementCountNeeded))
              } else {
                skipAppend = true
              }
            }
            prevResult = result
          }
          if !skipAppend {
            results.append(result)
          }
        } catch {
          logs.debug("Error: \(error.localizedDescription)")
        }
      }

      // MARK: Merge results

      let finalWords = lastAgreedWords + findLongestDifferentSuffix(prevWords, hypothesisWords)
      confirmedWords.append(contentsOf: finalWords)

      let mergedResult = mergeTranscriptionResults(results, confirmedWords: confirmedWords)

      DispatchQueue.main.async {
        logs.debug("Setting transcription status to done for task ID: \(taskId)")
        task.recording.transcription?.segments = mergedResult.segments.map(\.asSimpleSegment)
        task.recording.transcription?.text = mergedResult.text
        task.recording.transcription?.status = .done(Date())
      }
    } catch {
      DispatchQueue.main.async {
        logs.error("Error during transcription for task ID \(taskId): \(error.localizedDescription)")
        task.recording.transcription?.status = .error(message: error.localizedDescription)
      }
    }
  }
}
