import AVFoundation
import Foundation

func getFileDuration(url: URL) throws -> TimeInterval {
  let audioPlayer = try AVAudioPlayer(contentsOf: url)
  return audioPlayer.duration
}
