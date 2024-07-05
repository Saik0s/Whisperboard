import Foundation

// MARK: - Settings

public struct Settings: Hashable {
  public var useMockedClients: Bool
  public var selectedModelName: String
  public var parameters: TranscriptionParameters
  public var isICloudSyncEnabled: Bool
  public var shouldMixWithOtherAudio: Bool
  public var isUsingGPU: Bool
  public var isUsingNeuralEngine: Bool
  public var isVADEnabled: Bool
  public var isLiveTranscriptionEnabled: Bool

  public var voiceLanguage: String? {
    get { parameters.language }
    set { parameters.language = newValue }
  }

  public init(
    useMockedClients: Bool = false,
    selectedModelName: String = "tiny",
    parameters: TranscriptionParameters = TranscriptionParameters(),
    isICloudSyncEnabled: Bool = false,
    shouldMixWithOtherAudio: Bool = false,
    isUsingGPU: Bool = false,
    isUsingNeuralEngine: Bool = true,
    isVADEnabled: Bool = false,
    isLiveTranscriptionEnabled: Bool = false
  ) {
    self.useMockedClients = useMockedClients
    self.selectedModelName = selectedModelName
    self.parameters = parameters
    self.isICloudSyncEnabled = isICloudSyncEnabled
    self.shouldMixWithOtherAudio = shouldMixWithOtherAudio
    self.isUsingGPU = isUsingGPU
    self.isUsingNeuralEngine = isUsingNeuralEngine
    self.isVADEnabled = isVADEnabled
    self.isLiveTranscriptionEnabled = isLiveTranscriptionEnabled
  }
}

// MARK: Codable

extension Settings: Codable {
  enum CodingKeys: String, CodingKey {
    case useMockedClients
    case selectedModelName
    case parameters
    case isICloudSyncEnabled
    case shouldMixWithOtherAudio
    case isUsingGPU
    case isUsingNeuralEngine
    case isVADEnabled
    case isLiveTranscriptionEnabled
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    useMockedClients = (try? container.decode(Bool.self, forKey: .useMockedClients)) ?? false
    selectedModelName = (try? container.decode(String.self, forKey: .selectedModelName)) ?? "tiny"
    parameters = (try? container.decode(TranscriptionParameters.self, forKey: .parameters)) ?? TranscriptionParameters()
    isICloudSyncEnabled = (try? container.decode(Bool.self, forKey: .isICloudSyncEnabled)) ?? false
    shouldMixWithOtherAudio = (try? container.decode(Bool.self, forKey: .shouldMixWithOtherAudio)) ?? false
    isUsingGPU = (try? container.decode(Bool.self, forKey: .isUsingGPU)) ?? false
    isUsingNeuralEngine = (try? container.decode(Bool.self, forKey: .isUsingNeuralEngine)) ?? true
    isVADEnabled = (try? container.decode(Bool.self, forKey: .isVADEnabled)) ?? false
    isLiveTranscriptionEnabled = (try? container.decode(Bool.self, forKey: .isLiveTranscriptionEnabled)) ?? false
  }
}
