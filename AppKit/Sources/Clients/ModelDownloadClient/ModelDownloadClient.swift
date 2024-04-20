import Dependencies
import Foundation
import IdentifiedCollections

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
        VoiceModelType.allCases
          .map {
            let filePath = $0.localURL.path
            let fileExists = FileManager.default.fileExists(atPath: filePath)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? NSNumber)?.intValue ?? 0
            let isDownloaded = fileExists && fileSize > 10 * 1024 * 1024
            if fileExists && !isDownloaded {
              try? FileManager.default.removeItem(atPath: filePath)
            }
            return VoiceModel(
              modelType: $0,
              downloadProgress: isDownloaded ? 1 : 0
            )
          }
      },

      downloadModel: { modelType in
        AsyncStream<DownloadState>(bufferingPolicy: .bufferingNewest(1)) { continuation in
          Task {
            try FileManager.default.createDirectory(at: VoiceModelType.localFolderURL, withIntermediateDirectories: true)
            let destination = modelType.localURL

            let task = session.downloadTask(with: modelType.remoteURL)

            delegate.addDownloadTask(task) {
              continuation.yield(.inProgress($0))
            } onComplete: { result in
              switch result {
              case let .success(url):
                do {
                  let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
                  guard fileSize > 10 * 1024 * 1024 else {
                    throw NSError(
                      domain: "Error while downloading model",
                      code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "There was an error while downloading \(modelType.readableName) model"]
                    )
                  }
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
              log.verbose("Download finished")
            }

            continuation.yield(.inProgress(0))
            task.resume()

            continuation.onTermination = { termination in
              if termination == .cancelled {
                task.cancel()
                log.debug("Download cancelled")
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

  static let previewValue: ModelDownloadClient = {
    let downloadedModels: LockIsolated<IdentifiedArrayOf<VoiceModel>> = LockIsolated(
      VoiceModelType.allCases
        .map { VoiceModel(modelType: $0, downloadProgress: 0) }
        .identifiedArray
    )
    @Dependency(\.continuousClock) var clock: any Clock<Duration>

    return ModelDownloadClient(
      getModels: {
        VoiceModelType.allCases.map {
          downloadedModels.value[id: $0.fileName] ?? VoiceModel(
            modelType: $0,
            downloadProgress: 0
          )
        }
      },

      downloadModel: { modelType in
        AsyncStream<DownloadState>(bufferingPolicy: .bufferingNewest(1)) { continuation in
          Task {
            continuation.yield(.inProgress(0))
            try await clock.sleep(for: .seconds(1))
            continuation.yield(.inProgress(0.5))
            try await clock.sleep(for: .seconds(1))
            continuation.yield(.inProgress(1))
            try await clock.sleep(for: .seconds(1))
            let model = VoiceModel(modelType: modelType, downloadProgress: 1)
            downloadedModels.withValue { $0[id: modelType.fileName] = model }
            continuation.yield(.success(fileURL: URL(fileURLWithPath: "")))
            continuation.finish()
          }
        }
      },

      deleteModel: { modelType in
        downloadedModels.withValue { $0[id: modelType.fileName] = VoiceModel(modelType: modelType, downloadProgress: 0) }
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
