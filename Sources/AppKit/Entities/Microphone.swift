import AVFoundation

// MARK: - Microphone

struct Microphone: Hashable, Identifiable {
  var id: String { port.uid }

  var port: AVAudioSessionPortDescription

  var isBuiltIn: Bool {
    port.portType == .builtInMic
  }
}

extension Microphone {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: Microphone, rhs: Microphone) -> Bool {
    if lhs.id != rhs.id { return false }
    return true
  }
}
