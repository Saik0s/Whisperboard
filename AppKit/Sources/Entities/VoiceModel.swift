
import Foundation

// MARK: - VoiceModel

struct VoiceModel: Equatable, Identifiable, Then {
  var id: String { name }
  var name: String { modelType.fileName }
  var modelType: VoiceModelType
  var downloadProgress: Double = 0
  var isDownloaded: Bool { downloadProgress >= 1 }
  var isDownloading: Bool = false
}

// MARK: - VoiceModelType

enum VoiceModelType: String, CaseIterable, Codable, Equatable {
  case tinyEN = "tiny.en"
  case tiny
  case baseEN = "base.en"
  case base
  case smallEN = "small.en"
  case small
  case mediumEN = "medium.en"
  case medium
  case large

  var fileName: String { "ggml-\(rawValue).bin" }

  var readableName: String {
    switch self {
    case .tinyEN: return "Tiny (English)"
    case .tiny: return "Tiny"
    case .baseEN: return "Base (English)"
    case .base: return "Base"
    case .smallEN: return "Small (English)"
    case .small: return "Small"
    case .mediumEN: return "Medium (English)"
    case .medium: return "Medium"
    case .large: return "Large"
    }
  }

  var modelDescription: String {
    switch self {
    case .tinyEN: return "The English-specific version of the tiny model."
    case .tiny: return "A fast, compact model with decent accuracy."
    case .baseEN: return "The English-specific version of the base model."
    case .base: return "A larger model that provides better accuracy at the cost of some speed."
    case .smallEN: return "The English-specific version of the small model."
    case .small: return "A well-balanced model, offering a good compromise between size and accuracy."
    case .mediumEN: return "The English-specific version of the medium model."
    case .medium: return "A more powerful model with even better accuracy."
    case .large: return "The largest and most accurate model available, but it's also the slowest and most resource-intensive."
    }
  }

  var sizeLabel: String {
    switch self {
    case .tiny, .tinyEN: return "75 MB"
    case .base, .baseEN: return "142 MB"
    case .small, .smallEN: return "466 MB"
    case .medium, .mediumEN: return "1.5 GB"
    case .large: return "2.9 GB"
    }
  }

  var memoryRequired: UInt64 {
    switch self {
    case .tiny, .tinyEN: return 125 * 1024 * 1024
    case .base, .baseEN: return 210 * 1024 * 1024
    case .small, .smallEN: return 600 * 1024 * 1024
    case .medium, .mediumEN: return 1700 * 1024 * 1024
    case .large: return 3300 * 1024 * 1024
    }
  }

  var remoteURL: URL {
    VoiceModelType.srcURL.appending(component: fileName)
  }

  var localURL: URL {
    switch self {
    case .tiny:
      return Files.AppKit.Resources.ggmlTinyBin.url

    default:
      return VoiceModelType.localFolderURL.appending(component: fileName)
    }
  }

  private static var srcURL: URL {
    URL(staticString: "https://huggingface.co/saik0s/whisper.cpp/resolve/main/")
  }

  static var localFolderURL: URL {
    try! FileManager.default
      .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appending(path: "Models")
  }

  static var `default`: VoiceModelType { .tiny }
}

#if DEBUG

  extension VoiceModel {
    static let fixture = VoiceModel(modelType: .tiny)
  }
#endif
