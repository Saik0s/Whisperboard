import AppDevUtils
import Dependencies
import Foundation

// MARK: - ModelDownloadClient

struct ModelDownloadClient {
  var getModels: @Sendable () -> [VoiceModel]
  var downloadModel: @Sendable (_ model: VoiceModelType) async -> AsyncStream<DownloadState>
  var deleteModel: @Sendable (_ model: VoiceModelType) -> Void
}

// MARK: DependencyKey

extension ModelDownloadClient: DependencyKey {
  static let liveValue: Self = {
    let config: URLSessionConfiguration = .background(withIdentifier: "me.igortarasenko.whisperboard.background")
    config.isDiscretionary = false

    let delegate = SessionDelegate()
    let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

    return ModelDownloadClient(
      getModels: {
        VoiceModelType.allCases.map {
          VoiceModel(
            modelType: $0,
            downloadProgress: FileManager.default.fileExists(atPath: $0.localURL.path) ? 1 : 0
          )
        }
      },

      downloadModel: { modelType in
        AsyncStream<DownloadState>(bufferingPolicy: .bufferingNewest(1)) { continuation in
          Task {
            // ------------------------------------------------------------------
            // TODO: remove after some time, it is just to clean up old models folder
            if UserDefaults.standard.bool(forKey: "didCleanUpOldModelsFolder") == false {
              let oldModelsFolder = try? FileManager.default
                .url(for: .documentationDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "Models")
              if let oldModelsFolder, FileManager.default.fileExists(atPath: oldModelsFolder.path) {
                try? FileManager.default.removeItem(at: oldModelsFolder)
              }
              UserDefaults.standard.set(true, forKey: "didCleanUpOldModelsFolder")
            }
            // ------------------------------------------------------------------

            try FileManager.default.createDirectory(at: VoiceModelType.localFolderURL, withIntermediateDirectories: true)
            let destination = modelType.localURL

            let task = session.downloadTask(with: modelType.remoteURL)

            delegate.addDownloadTask(task) {
              continuation.yield(.inProgress($0))
            } onComplete: { result in
              switch result {
              case let .success(url):
                do {
                  try? FileManager.default.removeItem(at: destination)
                  try FileManager.default.moveItem(at: url, to: destination)
                  continuation.yield(.success(fileURL: url))
                } catch {
                  continuation.yield(.failure(error))
                  log.error(error)
                }
              case let .failure(error):
                continuation.yield(.failure(error))
                log.error(error)
              }
              continuation.finish()
            }

            continuation.yield(.inProgress(0))
            task.resume()

            continuation.onTermination = { termination in
              if termination == .cancelled {
                task.cancel()
              }
            }
          }
        }
      },

      deleteModel: { modelType in
        log.verbose("Deleting model \(modelType)...")
        try? FileManager.default.removeItem(at: modelType.localURL)
        log.verbose("Deleted model \(modelType)")
      }
    )
  }()
}

extension DependencyValues {
  var modelDownload: ModelDownloadClient {
    get { self[ModelDownloadClient.self] }
    set { self[ModelDownloadClient.self] = newValue }
  }
}
