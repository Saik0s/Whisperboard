import Foundation

// MARK: - VoiceModel

struct VoiceModel: Equatable, Identifiable, Then {
  var id: String { name }
  var name: String { modelType.fileName }
  var modelType: VoiceModelType
  var downloadProgress: Double = 0
  var isDownloaded: Bool { downloadProgress >= 1 }
  var isDownloading: Bool = false
  var isQuantizedModel: Bool { modelType.isQuantizedModel }
}

// MARK: - VoiceModelType

enum VoiceModelType: CaseIterable, Codable, Equatable {
  case tiny
  case tinyQuantized
  case tinyEN
  case tinyENQuantized
  case small
  case smallQuantized
  case smallEN
  case smallENQuantized
  case base
  case baseQuantized
  case baseEN
  case baseENQuantized
  case medium
  case mediumQuantized
  case mediumEN
  case mediumENQuantized
  case largeV1
  case largeV2
  case largeV2Quantized
  case largeV3
  case largeV3Quantized

  var fileName: String {
    switch self {
    case .tinyEN: return "ggml-tiny.en.bin"
    case .tiny: return "ggml-tiny.bin"
    case .baseEN: return "ggml-base.en.bin"
    case .base: return "ggml-base.bin"
    case .smallEN: return "ggml-small.en.bin"
    case .small: return "ggml-small.bin"
    case .mediumEN: return "ggml-medium.en.bin"
    case .medium: return "ggml-medium.bin"
    case .largeV1: return "ggml-large-v1.bin"
    case .largeV2: return "ggml-large-v2.bin"
    case .largeV3: return "ggml-large-v3.bin"
    case .tinyQuantized: return "ggml-tiny-q5_1.bin"
    case .tinyENQuantized: return "ggml-tiny-en-q5_1.bin"
    case .baseQuantized: return "ggml-base-q5_1.bin"
    case .baseENQuantized: return "ggml-base-en-q5_1.bin"
    case .smallQuantized: return "ggml-small-q5_1.bin"
    case .smallENQuantized: return "ggml-small-en-q5_1.bin"
    case .mediumQuantized: return "ggml-medium-q5_0.bin"
    case .mediumENQuantized: return "ggml-medium-en-q5_0.bin"
    case .largeV2Quantized: return "ggml-large-v2-q5_0.bin"
    case .largeV3Quantized: return "ggml-large-v3-q5_0.bin"
    }
  }

  var isQuantizedModel: Bool {
    switch self {
    case .baseENQuantized, .baseQuantized, .largeV2Quantized, .largeV3Quantized, .mediumENQuantized, .mediumQuantized,
         .smallENQuantized, .smallQuantized, .tinyENQuantized, .tinyQuantized:
      return true
    default:
      return false
    }
  }

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
    case .largeV1: return "Large V1"
    case .largeV2: return "Large V2"
    case .largeV3: return "Large V3"
    case .baseENQuantized, .baseQuantized:
      return "Base Quantized"
    case .largeV2Quantized:
      return "Large V2 Quantized"
    case .largeV3Quantized:
      return "Large V3 Quantized"
    case .mediumENQuantized:
      return "Medium (English) Quantized"
    case .mediumQuantized:
      return "Medium Quantized"
    case .smallENQuantized:
      return "Small (English) Quantized"
    case .smallQuantized:
      return "Small Quantized"
    case .tinyENQuantized:
      return "Tiny (English) Quantized"
    case .tinyQuantized:
      return "Tiny Quantized"
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
    case .largeV1: return "Version 1 of the large model, with great accuracy and detail."
    case .largeV2: return "Version 2 of the large model, improved and optimized."
    case .largeV3: return "Version 3 of the large model, the latest and most advanced."
    case .baseENQuantized, .baseQuantized, .largeV2Quantized, .largeV3Quantized, .mediumENQuantized, .mediumQuantized,
         .smallENQuantized, .smallQuantized, .tinyENQuantized, .tinyQuantized:
      return "This is a quantized model that is smaller in size and requires less memory, but is still fast and accurate."
    }
  }

  var sizeLabel: String {
    switch self {
    case .tiny: return "78 MB"
    case .tinyEN: return "78 MB"
    case .tinyENQuantized, .tinyQuantized: return "32 MB"
    case .base: return "148 MB"
    case .baseEN: return "148 MB"
    case .baseENQuantized, .baseQuantized: return "60 MB"
    case .small: return "488 MB"
    case .smallEN: return "488 MB"
    case .smallENQuantized, .smallQuantized: return "190 MB"
    case .medium: return "1.5 GB"
    case .mediumEN: return "1.5 GB"
    case .mediumENQuantized, .mediumQuantized: return "539 MB"
    case .largeV1: return "3.1 GB"
    case .largeV2: return "3.1 GB"
    case .largeV2Quantized: return "1.1 GB"
    case .largeV3: return "3.1 GB"
    case .largeV3Quantized: return "1.1 GB"
    }
  }

  var memoryRequired: UInt64 {
    switch self {
    case .tiny: return 273 * 1024 * 1024
    case .tinyEN: return 273 * 1024 * 1024
    case .tinyENQuantized, .tinyQuantized: return 32 * 1024 * 1024
    case .base: return 388 * 1024 * 1024
    case .baseEN: return 388 * 1024 * 1024
    case .baseENQuantized, .baseQuantized: return 60 * 1024 * 1024
    case .small: return 852 * 1024 * 1024
    case .smallEN: return 852 * 1024 * 1024
    case .smallENQuantized, .smallQuantized: return 190 * 1024 * 1024
    case .medium: return 2100 * 1024 * 1024
    case .mediumEN: return 2100 * 1024 * 1024
    case .mediumENQuantized, .mediumQuantized: return 539 * 1024 * 1024
    case .largeV1: return 3900 * 1024 * 1024
    case .largeV2: return 3900 * 1024 * 1024
    case .largeV2Quantized: return 1100 * 1024 * 1024
    case .largeV3: return 3900 * 1024 * 1024
    case .largeV3Quantized: return 1100 * 1024 * 1024
    }
  }

  var remoteURL: URL {
    VoiceModelType.srcURL.appending(path: fileName)
  }

  var localURL: URL {
    switch self {
    case .tiny:
      return Files.AppKit.Resources.ggmlTinyBin.url

    default:
      return VoiceModelType.localFolderURL.appending(path: fileName)
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
