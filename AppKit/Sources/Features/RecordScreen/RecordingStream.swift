//
//import WhisperKit
//
//@Reducer
//struct Transcription {
//  @ObservableState
//  struct State: Equatable {
//    var transcriptionText: String = ""
//    var isTranscribing: Bool = false
//    var error: Error?
//  }
//
//  enum Action: Equatable {
//    case startTranscription
//    case updateTranscription(String)
//    case transcriptionError(Error)
//    case stopTranscription
//  }
//
//  init() {
//    func loadModel(_ model: String, redownload: Bool = false) {
//        print("Selected Model: \(UserDefaults.standard.string(forKey: "selectedModel") ?? "nil")")
//
//        whisperKit = nil
//        Task {
//            whisperKit = try await WhisperKit(
//                verbose: true,
//                logLevel: .debug,
//                prewarm: false,
//                load: false,
//                download: false
//            )
//            guard let whisperKit = whisperKit else {
//                return
//            }
//
//            var folder: URL?
//
//            // Check if the model is available locally
//            if localModels.contains(model) && !redownload {
//                // Get local model folder URL from localModels
//                // TODO: Make this configurable in the UI
//                folder = URL(fileURLWithPath: localModelPath).appendingPathComponent(model)
//            } else {
//                // Download the model
//                folder = try await WhisperKit.download(variant: model, from: repoName, progressCallback: { progress in
//                    DispatchQueue.main.async {
//                        loadingProgressValue = Float(progress.fractionCompleted) * specializationProgressRatio
//                        modelState = .downloading
//                    }
//                })
//            }
//
//            await MainActor.run {
//                loadingProgressValue = specializationProgressRatio
//                modelState = .downloaded
//            }
//
//            if let modelFolder = folder {
//                whisperKit.modelFolder = modelFolder
//
//                await MainActor.run {
//                    // Set the loading progress to 90% of the way after prewarm
//                    loadingProgressValue = specializationProgressRatio
//                    modelState = .prewarming
//                }
//
//                let progressBarTask = Task {
//                    await updateProgressBar(targetProgress: 0.9, maxTime: 240)
//                }
//
//                // Prewarm models
//                do {
//                    try await whisperKit.prewarmModels()
//                    progressBarTask.cancel()
//                } catch {
//                    print("Error prewarming models, retrying: \(error.localizedDescription)")
//                    progressBarTask.cancel()
//                    if !redownload {
//                        loadModel(model, redownload: true)
//                        return
//                    } else {
//                        // Redownloading failed, error out
//                        modelState = .unloaded
//                        return
//                    }
//                }
//
//                await MainActor.run {
//                    // Set the loading progress to 90% of the way after prewarm
//                    loadingProgressValue = specializationProgressRatio + 0.9 * (1 - specializationProgressRatio)
//                    modelState = .loading
//                }
//
//                try await whisperKit.loadModels()
//
//                await MainActor.run {
//                    if !localModels.contains(model) {
//                        localModels.append(model)
//                    }
//
//                    availableLanguages = Constants.languages.map { $0.key }.sorted()
//                    loadingProgressValue = 1.0
//                    modelState = whisperKit.modelState
//                }
//            }
//        }
//    }
//  }
//
//
//  func reduce(into state: inout State, action: Action) -> Effect<Action> {
//    switch action {
//    case .startTranscription:
//      state.isTranscribing = true
//      state.error = nil
//      return startTranscriptionEffect()
//
//    case let .updateTranscription(text):
//      state.transcriptionText = text
//      return .none
//
//    case let .transcriptionError(error):
//      state.isTranscribing = false
//      state.error = error
//      return .none
//
//    case .stopTranscription:
//      state.isTranscribing = false
//      return .none
//    }
//  }
//
//  private func startTranscriptionEffect() -> Effect<Action> {
//    .run { [audioRecorder, whisperKit] send in
//      let audioURL = audioRecorder.currentRecordingURL
//      guard let audioData = try? Data(contentsOf: audioURL) else {
//        await send(.transcriptionError(TranscriptionError.audioDataUnavailable))
//        return
//      }
//
//      do {
//        let transcriptionResults = try await whisperKit.transcribe(audioData: audioData)
//        for result in transcriptionResults {
//          await send(.updateTranscription(result.text))
//        }
//      } catch {
//        await send(.transcriptionError(error))
//      }
//    }
//  }
//}
//
//enum TranscriptionError: Error, Equatable {
//  case audioDataUnavailable
//}
//
