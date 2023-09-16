import Foundation

// MARK: - Settings

struct Settings: Hashable, Then {
  var isRemoteTranscriptionEnabled: Bool = false
  var useMockedClients: Bool = false
  var selectedModel: VoiceModelType = .default
  var parameters = TranscriptionParameters()
  var isICloudSyncEnabled: Bool = false

  var voiceLanguage: VoiceLanguage {
    get { parameters.language }
    set { parameters.language = newValue }
  }
}

// MARK: Codable

extension Settings: Codable {
  enum CodingKeys: String, CodingKey {
    case isRemoteTranscriptionEnabled
    case useMockedClients
    case selectedModel
    case parameters
    case isICloudSyncEnabled
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isRemoteTranscriptionEnabled = (try? container.decode(Bool.self, forKey: .isRemoteTranscriptionEnabled)) ?? false
    useMockedClients = (try? container.decode(Bool.self, forKey: .useMockedClients)) ?? false
    selectedModel = (try? container.decode(VoiceModelType.self, forKey: .selectedModel)) ?? .default
    parameters = (try? container.decode(TranscriptionParameters.self, forKey: .parameters)) ?? TranscriptionParameters()
    isICloudSyncEnabled = (try? container.decode(Bool.self, forKey: .isICloudSyncEnabled)) ?? false
  }
}
