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
      progress

    case .success:
      1

    case .failure:
      0
    }
  }

  var isDownloading: Bool {
    switch self {
    case .inProgress:
      true

    case .failure, .success:
      false
    }
  }

  var error: Error? {
    switch self {
    case .inProgress, .success:
      nil

    case let .failure(error):
      error
    }
  }

  var isDownloaded: Bool {
    switch self {
    case .success:
      true

    case .failure, .inProgress:
      false
    }
  }
}
