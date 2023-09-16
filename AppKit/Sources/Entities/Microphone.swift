import AVFoundation

// MARK: - Microphone

struct Microphone: Hashable {
  var id: String { port.uid }

  var port: AVAudioSessionPortDescription
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
