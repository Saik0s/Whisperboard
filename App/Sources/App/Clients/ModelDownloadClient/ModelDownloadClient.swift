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

    return ModelDownloadClient(
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
                  try FileManager.default.removeItem(at: destination)
                  try FileManager.default.moveItem(at: url, to: destination)
                  continuation.yield(.success(fileURL: url))
                } catch {
                  continuation.yield(.failure(error))
                  log(error)
                }
              case let .failure(error):
                continuation.yield(.failure(error))
                log(error)
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

// MARK: - DownloadTaskContainer

struct DownloadTaskContainer {
  weak var task: URLSessionDownloadTask?
  let onProgressUpdate: (Double) -> Void
  let onComplete: (Result<URL, Error>) -> Void
}

// MARK: - UploadTaskContainer

struct UploadTaskContainer {
  weak var task: URLSessionUploadTask?
  let onProgressUpdate: (Double) -> Void
  let onComplete: (Result<Void, Error>) -> Void
}

// MARK: - SessionDelegate

class SessionDelegate: NSObject, URLSessionDownloadDelegate {
  private var downloadTasks: [DownloadTaskContainer] = []
  private var uploadTasks: [UploadTaskContainer] = []

  func addDownloadTask(
    _ task: URLSessionDownloadTask,
    onProgressUpdate: @escaping (Double) -> Void,
    onComplete: @escaping (Result<URL, Error>) -> Void
  ) {
    downloadTasks.append(DownloadTaskContainer(task: task, onProgressUpdate: onProgressUpdate, onComplete: onComplete))
  }

  func addUploadTask(
    _ task: URLSessionUploadTask,
    onProgressUpdate: @escaping (Double) -> Void,
    onComplete: @escaping (Result<Void, Error>) -> Void
  ) {
    uploadTasks.append(UploadTaskContainer(task: task, onProgressUpdate: onProgressUpdate, onComplete: onComplete))
  }

  func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    for taskContainer in downloadTasks where taskContainer.task == downloadTask {
      taskContainer.onComplete(.success(location))
    }
  }

  func urlSession(
    _: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData _: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    for taskContainer in downloadTasks where taskContainer.task == downloadTask {
      let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
      taskContainer.onProgressUpdate(progress)
    }
  }

  func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error {
      for taskContainer in downloadTasks where taskContainer.task == task {
        taskContainer.onComplete(.failure(error))
      }
      for taskContainer in uploadTasks where taskContainer.task == task {
        taskContainer.onComplete(.failure(error))
      }
    } else {
      for taskContainer in uploadTasks where taskContainer.task == task {
        taskContainer.onComplete(.success(()))
      }
    }
  }

  func urlSession(
    _: URLSession,
    task: URLSessionTask,
    didSendBodyData _: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    for taskContainer in uploadTasks where taskContainer.task == task {
      let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
      taskContainer.onProgressUpdate(progress)
    }
  }
}
