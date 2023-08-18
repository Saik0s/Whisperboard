import BetterCodable
import Foundation

struct Settings: Codable, Hashable {
  var isParallelEnabled: Bool = false
  var isRemoteTranscriptionEnabled: Bool = false
  @DefaultFalse var useMockedClients: Bool = false
  var selectedModel: VoiceModelType = .default
  var parameters = TranscriptionParameters()
  var voiceLanguage: VoiceLanguage {
    get { parameters.language }
    set { parameters.language = newValue }
  }
}
