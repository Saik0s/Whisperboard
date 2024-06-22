import Foundation

// MARK: - DownloadTaskContainer

public struct DownloadTaskContainer {
  public weak var task: URLSessionDownloadTask?
  public let onProgressUpdate: (Double) -> Void
  public let onComplete: (Result<URL, Error>) -> Void

  public init(task: URLSessionDownloadTask?, onProgressUpdate: @escaping (Double) -> Void, onComplete: @escaping (Result<URL, Error>) -> Void) {
    self.task = task
    self.onProgressUpdate = onProgressUpdate
    self.onComplete = onComplete
  }
}

// MARK: - UploadTaskContainer

public struct UploadTaskContainer {
  public weak var task: URLSessionUploadTask?
  public let onProgressUpdate: (Double) -> Void
  public let onComplete: (Result<Void, Error>) -> Void

  public init(task: URLSessionUploadTask?, onProgressUpdate: @escaping (Double) -> Void, onComplete: @escaping (Result<Void, Error>) -> Void) {
    self.task = task
    self.onProgressUpdate = onProgressUpdate
    self.onComplete = onComplete
  }
}

// MARK: - SessionDelegate

public class SessionDelegate: NSObject, URLSessionDownloadDelegate {
  private var downloadTasks: [DownloadTaskContainer] = []
  private var uploadTasks: [UploadTaskContainer] = []

  public func addDownloadTask(
    _ task: URLSessionDownloadTask,
    onProgressUpdate: @escaping (Double) -> Void,
    onComplete: @escaping (Result<URL, Error>) -> Void
  ) {
    downloadTasks.append(DownloadTaskContainer(task: task, onProgressUpdate: onProgressUpdate, onComplete: onComplete))
  }

  public func addUploadTask(
    _ task: URLSessionUploadTask,
    onProgressUpdate: @escaping (Double) -> Void,
    onComplete: @escaping (Result<Void, Error>) -> Void
  ) {
    uploadTasks.append(UploadTaskContainer(task: task, onProgressUpdate: onProgressUpdate, onComplete: onComplete))
  }

  public func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    for taskContainer in downloadTasks where taskContainer.task == downloadTask {
      taskContainer.onComplete(.success(location))
    }
  }

  public func urlSession(
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

  public func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
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

  public func urlSession(
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
