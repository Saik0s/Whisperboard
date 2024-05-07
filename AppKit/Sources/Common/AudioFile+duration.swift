import AVFoundation
import Foundation

func getFileDuration(url fileURL: URL) async throws -> TimeInterval {
  let asset = AVURLAsset(url: fileURL, options: nil)
  let duration: CMTime = try await asset.load(.duration)
  let value = Double(duration.value)
  let timescale = Double(duration.timescale)
  let totalDuration = value / timescale
  return totalDuration
}
