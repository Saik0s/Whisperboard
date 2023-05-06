import Foundation

// MARK: - DownloadState

enum DownloadState {
  case inProgress(Double)
  case success(fileURL: URL)
  case failure(Error)
}

extension DownloadState {
  var progress: Double {
    switch self {
    case let .inProgress(progress):
      return progress
    case .success:
      return 1
    case .failure:
      return 0
    }
  }

  var isDownloading: Bool {
    switch self {
    case .inProgress:
      return true
    case .success, .failure:
      return false
    }
  }

  var error: Error? {
    switch self {
    case .inProgress, .success:
      return nil
    case let .failure(error):
      return error
    }
  }

  var isDownloaded: Bool {
    switch self {
    case .success:
      return true
    case .inProgress, .failure:
      return false
    }
  }
}
