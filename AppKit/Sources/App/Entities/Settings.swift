import AppDevUtils
import BetterCodable
import Foundation

struct Settings: Codable, Hashable, Then {
  var isRemoteTranscriptionEnabled: Bool = false
  @DefaultFalse var useMockedClients: Bool = false
  var selectedModel: VoiceModelType = .default
  var parameters = TranscriptionParameters()
  @DefaultFalse var isICloudSyncEnabled: Bool = false

  var voiceLanguage: VoiceLanguage {
    get { parameters.language }
    set { parameters.language = newValue }
  }
}
