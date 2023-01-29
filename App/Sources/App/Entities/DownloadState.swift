import Foundation

enum DownloadState {
  case inProgress(Double)
  case success(fileURL: URL)
  case failure(Error)
}
