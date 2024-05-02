import Foundation

// MARK: - VoiceModel

struct VoiceModel: Equatable, Identifiable, Then {
  var id: String { name }
  var name: String { modelType.fileName }
  var modelType: VoiceModelType
  var downloadProgress: Double = 0
  var isDownloaded: Bool { downloadProgress >= 1 }
  var isDownloading = false
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
    case .tinyEN: "ggml-tiny.en.bin"
    case .tiny: "ggml-tiny.bin"
    case .baseEN: "ggml-base.en.bin"
    case .base: "ggml-base.bin"
    case .smallEN: "ggml-small.en.bin"
    case .small: "ggml-small.bin"
    case .mediumEN: "ggml-medium.en.bin"
    case .medium: "ggml-medium.bin"
    case .largeV1: "ggml-large-v1.bin"
    case .largeV2: "ggml-large-v2.bin"
    case .largeV3: "ggml-large-v3.bin"
    case .tinyQuantized: "ggml-tiny-q5_1.bin"
    case .tinyENQuantized: "ggml-tiny.en-q5_1.bin"
    case .baseQuantized: "ggml-base-q5_1.bin"
    case .baseENQuantized: "ggml-base.en-q5_1.bin"
    case .smallQuantized: "ggml-small-q5_1.bin"
    case .smallENQuantized: "ggml-small.en-q5_1.bin"
    case .mediumQuantized: "ggml-medium-q5_0.bin"
    case .mediumENQuantized: "ggml-medium.en-q5_0.bin"
    case .largeV2Quantized: "ggml-large-v2-q5_0.bin"
    case .largeV3Quantized: "ggml-large-v3-q5_0.bin"
    }
  }

  var isQuantizedModel: Bool {
    switch self {
    case .baseENQuantized, .baseQuantized, .largeV2Quantized, .largeV3Quantized, .mediumENQuantized, .mediumQuantized,
         .smallENQuantized, .smallQuantized, .tinyENQuantized, .tinyQuantized:
      true

    default:
      false
    }
  }

  var readableName: String {
    switch self {
    case .tinyEN: "Tiny (English)"
    case .tiny: "Tiny"
    case .baseEN: "Base (English)"
    case .base: "Base"
    case .smallEN: "Small (English)"
    case .small: "Small"
    case .mediumEN: "Medium (English)"
    case .medium: "Medium"
    case .largeV1: "Large V1"
    case .largeV2: "Large V2"
    case .largeV3: "Large V3"
    case .baseENQuantized:
      "Base (English) Quantized"
    case .baseQuantized:
      "Base Quantized"
    case .largeV2Quantized:
      "Large V2 Quantized"
    case .largeV3Quantized:
      "Large V3 Quantized"
    case .mediumENQuantized:
      "Medium (English) Quantized"
    case .mediumQuantized:
      "Medium Quantized"
    case .smallENQuantized:
      "Small (English) Quantized"
    case .smallQuantized:
      "Small Quantized"
    case .tinyENQuantized:
      "Tiny (English) Quantized"
    case .tinyQuantized:
      "Tiny Quantized"
    }
  }

  var modelDescription: String {
    switch self {
    case .tinyEN: "The English-specific version of the tiny model."
    case .tiny: "A fast, compact model with decent accuracy."
    case .baseEN: "The English-specific version of the base model."
    case .base: "A larger model that provides better accuracy at the cost of some speed."
    case .smallEN: "The English-specific version of the small model."
    case .small: "A well-balanced model, offering a good compromise between size and accuracy."
    case .mediumEN: "The English-specific version of the medium model."
    case .medium: "A more powerful model with even better accuracy."
    case .largeV1: "Version 1 of the large model, with great accuracy and detail."
    case .largeV2: "Version 2 of the large model, improved and optimized."
    case .largeV3: "Version 3 of the large model, the latest and most advanced."
    case .baseENQuantized, .baseQuantized, .largeV2Quantized, .largeV3Quantized, .mediumENQuantized, .mediumQuantized,
         .smallENQuantized, .smallQuantized, .tinyENQuantized, .tinyQuantized:
      "This is a quantized model that is smaller in size and requires less memory, but is still fast and accurate."
    }
  }

  var sizeLabel: String {
    switch self {
    case .tiny: "78 MB"
    case .tinyEN: "78 MB"
    case .tinyENQuantized, .tinyQuantized: "32 MB"
    case .base: "148 MB"
    case .baseEN: "148 MB"
    case .baseENQuantized, .baseQuantized: "60 MB"
    case .small: "488 MB"
    case .smallEN: "488 MB"
    case .smallENQuantized, .smallQuantized: "190 MB"
    case .medium: "1.5 GB"
    case .mediumEN: "1.5 GB"
    case .mediumENQuantized, .mediumQuantized: "539 MB"
    case .largeV1: "3.1 GB"
    case .largeV2: "3.1 GB"
    case .largeV2Quantized: "1.1 GB"
    case .largeV3: "3.1 GB"
    case .largeV3Quantized: "1.1 GB"
    }
  }

  var memoryRequired: UInt64 {
    switch self {
    case .tiny: 273 * 1024 * 1024
    case .tinyEN: 273 * 1024 * 1024
    case .tinyENQuantized, .tinyQuantized: 32 * 1024 * 1024
    case .base: 388 * 1024 * 1024
    case .baseEN: 388 * 1024 * 1024
    case .baseENQuantized, .baseQuantized: 60 * 1024 * 1024
    case .small: 852 * 1024 * 1024
    case .smallEN: 852 * 1024 * 1024
    case .smallENQuantized, .smallQuantized: 190 * 1024 * 1024
    case .medium: 2100 * 1024 * 1024
    case .mediumEN: 2100 * 1024 * 1024
    case .mediumENQuantized, .mediumQuantized: 539 * 1024 * 1024
    case .largeV1: 3900 * 1024 * 1024
    case .largeV2: 3900 * 1024 * 1024
    case .largeV2Quantized: 1100 * 1024 * 1024
    case .largeV3: 3900 * 1024 * 1024
    case .largeV3Quantized: 1100 * 1024 * 1024
    }
  }

  var remoteURL: URL {
    Self.srcURL.appending(path: fileName)
  }

  var localURL: URL {
    switch self {
    case .tiny:
      Files.AppKit.Resources.ggmlTinyBin.url

    default:
      Self.localFolderURL.appending(path: fileName)
    }
  }

  private static var srcURL: URL {
    URL(staticString: "https://huggingface.co/saik0s/whisper.cpp/resolve/main/")
  }

  static var localFolderURL: URL {
    URL.documentsDirectory.appending(path: "Models")
  }

  static var `default`: Self { .tiny }
}

#if DEBUG
  extension VoiceModel {
    static let fixture = VoiceModel(modelType: .tiny)
  }
#endif
