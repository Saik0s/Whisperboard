//
// Created by Igor Tarasenko on 08/01/2023.
//

import Foundation

struct Model: Equatable, Identifiable, Then {
  var type: ModelType
  var isDownloading: Bool = false
  var downloadProgress: Double = 0

  var id: String { name }
  var name: String { type.name }
  var isDownloaded: Bool { downloadProgress >= 1 }
}

enum ModelType: String, CaseIterable {
  case tinyEN = "tiny.en"
  case tiny = "tiny"
  case baseEN = "base.en"
  case base = "base"
  case smallEN = "small.en"
  case small = "small"
  // case mediumEN = "medium.en"
  // case medium = "medium"
  // case largeV1 = "large-v1"
  // case large = "large"

  var name: String { "ggml-\(rawValue).bin" }

  var sizeLabel: String {
    switch self {
    case .tinyEN, .tiny: return "75 MB"
    case .baseEN, .base: return "142 MB"
    case .smallEN, .small: return "466 MB"
    // case .mediumEN, .medium: return "1.5 GB"
    // case .largeV1, .large: return "2.9 GB"
    }
  }

  var remoteURL: URL {
    ModelType.srcURL.appending(component: name)
  }

  var localURL: URL {
    ModelType.localFolderURL.appending(component: name)
  }

  private static var srcURL: URL {
    URL(string: "https://huggingface.co/datasets/ggerganov/whisper.cpp/resolve/main/")!
  }

  static var localFolderURL: URL {
    try! FileManager.default
      .url(for: .documentationDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appending(path: "Models")
  }
}
