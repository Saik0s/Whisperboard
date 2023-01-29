import AppDevUtils
import Foundation

// MARK: - ModelDownloadClient

struct ModelDownloadClient {
  var downloadModel: (_ model: VoiceModel) async -> AsyncStream<DownloadState>
}

extension ModelDownloadClient {
  static let live: Self = {
    let config: URLSessionConfiguration = .background(withIdentifier: "me.igortarasenko.whisperboard.background")
    config.isDiscretionary = false

    let delegate = SessionDelegate()
    let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

    return Self(
      downloadModel: { model in
        AsyncStream { continuation in
          Task {
            let progress = ProgressHandler { total, current in
              continuation.yield(.inProgress(Double(current) / Double(total)))
            }

            try FileManager.default.createDirectory(at: VoiceModelType.localFolderURL, withIntermediateDirectories: true)
            let destination = model.type.localURL

            delegate.progress = progress
            delegate.onComplete = { url in
              do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: url, to: destination)
                continuation.yield(.success(fileURL: url))
              } catch {
                continuation.yield(.failure(error))
                log(error)
              }
              continuation.finish()
            }

            let task = session.downloadTask(with: model.type.remoteURL)
            task.resume()
          }
        }
      }
    )
  }()
}

// MARK: - SessionDelegate

class SessionDelegate: NSObject, URLSessionDownloadDelegate {
  var progress: ProgressHandler?
  var onComplete: ((URL) -> Void)?

  override init() { super.init() }

  func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    log(location)
    onComplete?(location)
  }

  func urlSession(
    _: URLSession,
    downloadTask _: URLSessionDownloadTask,
    didWriteData _: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    progress?.completedUnitCount = totalBytesWritten
    progress?.totalUnitCount = totalBytesExpectedToWrite
  }
}

// MARK: - ProgressHandler

final class ProgressHandler {
  let closure: (_ total: Int64, _ current: Int64) -> Void

  var totalUnitCount: Int64 = 0 { didSet { closure(totalUnitCount, completedUnitCount) } }
  var completedUnitCount: Int64 = 0 { didSet { closure(totalUnitCount, completedUnitCount) } }

  init(closure: @escaping (Int64, Int64) -> Void) {
    self.closure = closure
  }
}
