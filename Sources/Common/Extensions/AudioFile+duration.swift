import AVFoundation
import Foundation

public func getFileDuration(url fileURL: URL) async throws -> TimeInterval {
  // Create an AVURLAsset with the provided file URL
  let asset = AVURLAsset(url: fileURL, options: nil)
  let duration: CMTime

  // Attempt to load the duration of the asset
  do {
    logs.debug("Attempting to load duration for URL: \(fileURL)")
    duration = try await asset.load(.duration)
    logs.debug("Successfully loaded duration: \(duration.seconds) seconds for URL: \(fileURL)")
  } catch {
    logs.error("Failed to load duration for URL: \(fileURL) with error: \(error)")
    throw error
  }

  // Calculate the total duration in seconds
  let value = Double(duration.value)
  let timescale = Double(duration.timescale)
  let totalDuration = value / timescale
  logs.debug("Duration value: \(value), timescale: \(timescale)")
  logs.debug("Calculated total duration: \(totalDuration) seconds for URL: \(fileURL)")

  return totalDuration
}
