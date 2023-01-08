//
// Created by Igor Tarasenko on 08/01/2023.
//

import Foundation

enum DownloadState {
  case inProgress(Double)
  case success(fileURL: URL)
  case failure(Error)
}
