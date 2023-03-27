import AppDevUtils
import Dependencies
import Foundation

// MARK: - ModelDownloadClient

struct ModelDownloadClient {
  var getModels: @Sendable () -> [VoiceModel]
  var downloadModel: @Sendable (_ model: VoiceModel) async -> AsyncStream<DownloadState>
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
      downloadModel: { model in
        AsyncStream { continuation in
          Task {
            try FileManager.default.createDirectory(at: VoiceModelType.localFolderURL, withIntermediateDirectories: true)
            let destination = model.modelType.localURL

            let task = session.downloadTask(with: model.modelType.remoteURL)

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
          }
        }
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
