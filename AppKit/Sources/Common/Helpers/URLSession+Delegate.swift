import Foundation

// MARK: - DownloadTaskContainer

struct DownloadTaskContainer {
  weak var task: URLSessionDownloadTask?
  let onProgressUpdate: (Double) -> Void
  let onComplete: (Result<URL, Error>) -> Void

  init(task: URLSessionDownloadTask?, onProgressUpdate: @escaping (Double) -> Void, onComplete: @escaping (Result<URL, Error>) -> Void) {
    self.task = task
    self.onProgressUpdate = onProgressUpdate
    self.onComplete = onComplete
  }
}

// MARK: - UploadTaskContainer

struct UploadTaskContainer {
  weak var task: URLSessionUploadTask?
  let onProgressUpdate: (Double) -> Void
  let onComplete: (Result<Void, Error>) -> Void

  init(task: URLSessionUploadTask?, onProgressUpdate: @escaping (Double) -> Void, onComplete: @escaping (Result<Void, Error>) -> Void) {
    self.task = task
    self.onProgressUpdate = onProgressUpdate
    self.onComplete = onComplete
  }
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
