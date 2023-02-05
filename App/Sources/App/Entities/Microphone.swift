import AVFoundation

// MARK: - Microphone

public struct Microphone: Hashable {
  var id: String { port.uid }
  var port: AVAudioSessionPortDescription
}

public extension Microphone {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: Microphone, rhs: Microphone) -> Bool {
    if lhs.id != rhs.id { return false }
    return true
  }
}
