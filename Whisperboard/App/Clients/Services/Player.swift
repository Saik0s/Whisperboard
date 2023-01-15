//
// Player.swift
//

import AVFoundation
import Foundation

class Player {
  private var audioPlayer: AVAudioPlayer?

  func startPlayback(_ url: URL) throws {
    audioPlayer = try AVAudioPlayer(contentsOf: url)
    audioPlayer?.play()
  }

  func stopPlayback() {
    audioPlayer?.stop()
    audioPlayer = nil
  }
}
