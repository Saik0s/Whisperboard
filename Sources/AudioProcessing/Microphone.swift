import AVFoundation

// MARK: - Microphone

public struct Microphone: Hashable, Equatable, Identifiable {
  #if os(iOS)
    public var id: String { port.uid }
    public var isBuiltIn: Bool { port.portType == .builtInMic }
    public var portName: String { port.portName }

    public let port: AVAudioSessionPortDescription

    public init(_ port: AVAudioSessionPortDescription) {
      self.port = port
    }
  #else
    public var id: String { "0" }
    public var isBuiltIn: Bool { false }

    public init() {}
  #endif
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
