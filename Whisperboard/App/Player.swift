//
// Created by Igor Tarasenko on 24/12/2022.
//

import Foundation
import AVFoundation

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
