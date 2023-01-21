import Foundation

// MARK: - ModelDownloadClient

struct ModelDownloadClient {
  var downloadModel: (_ model: VoiceModel) async -> AsyncStream<DownloadState>
}

extension ModelDownloadClient {
  static let live = Self(
    downloadModel: { model in
      AsyncStream { continuation in
        Task {
          do {
            let progress = ProgressHandler { total, current in
              continuation.yield(.inProgress(Double(current) / Double(total)))
            }

            try FileManager.default.createDirectory(at: VoiceModelType.localFolderURL, withIntermediateDirectories: true)
            let destination = model.type.localURL

            let (url, _) = try await URLSession.shared.download(from: model.type.remoteURL, progress: progress)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: url, to: destination)

            continuation.yield(.success(fileURL: destination))
          } catch {
            continuation.yield(.failure(error))
            log(error)
          }
        }
      }
    }
  )
}

// MARK: - DownloadError

enum DownloadError: Error {
  case cannotOpenFile
}

// MARK: - ProgressHandler

final class ProgressHandler {
  let closure: (_ total: Int64, _ current: Int64) -> Void

  var totalUnitCount: Int64 = 0 { didSet { closure(totalUnitCount, completedUnitCount) } }
  var completedUnitCount: Int64 = 0 { didSet { closure(totalUnitCount, completedUnitCount) } }

  init(closure: @escaping (Int64, Int64) -> Void) {
    self.closure = closure
  }
}

extension URLSession {
  func download(from url: URL, delegate: URLSessionTaskDelegate? = nil, progress: ProgressHandler) async throws -> (URL, URLResponse) {
    try await download(for: URLRequest(url: url), delegate: delegate, progress: progress)
  }

  func download(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil, progress: ProgressHandler) async throws -> (URL, URLResponse) {
    let bufferSize = 65536
    let estimatedSize: Int64 = 1_000_000

    let (asyncBytes, response) = try await bytes(for: request, delegate: delegate)
    let expectedLength = response.expectedContentLength // note, if server cannot provide expectedContentLength, this will be -1
    progress.totalUnitCount = expectedLength > 0 ? expectedLength : estimatedSize

    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
    guard let output = OutputStream(url: fileURL, append: false) else {
      throw DownloadError.cannotOpenFile
    }
    output.open()

    var buffer = Data()
    if expectedLength > 0 {
      buffer.reserveCapacity(min(bufferSize, Int(expectedLength)))
    } else {
      buffer.reserveCapacity(bufferSize)
    }

    var count: Int64 = 0
    for try await byte in asyncBytes {
      try Task.checkCancellation()

      count += 1
      buffer.append(byte)

      if buffer.count >= bufferSize {
        try output.write(buffer)
        buffer.removeAll(keepingCapacity: true)

        if expectedLength < 0 || count > expectedLength {
          progress.totalUnitCount = count + estimatedSize
        }
        progress.completedUnitCount = count
      }
    }

    if !buffer.isEmpty {
      try output.write(buffer)
    }

    output.close()

    progress.totalUnitCount = count
    progress.completedUnitCount = count

    return (fileURL, response)
  }
}

// MARK: - OutputStreamError

enum OutputStreamError: Error {
  case bufferFailure
  case writeFailure
}

extension OutputStream {
  /// Write `Data` to `OutputStream`
  ///
  /// - parameter data:                  The `Data` to write.

  func write(_ data: Data) throws {
    try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) throws in
      guard var pointer = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        throw OutputStreamError.bufferFailure
      }

      var bytesRemaining = buffer.count

      while bytesRemaining > 0 {
        let bytesWritten = write(pointer, maxLength: bytesRemaining)
        if bytesWritten < 0 {
          throw OutputStreamError.writeFailure
        }

        bytesRemaining -= bytesWritten
        pointer += bytesWritten
      }
    }
  }
}
