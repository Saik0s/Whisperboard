import AudioKit
import Dependencies
import Foundation

// MARK: - FileImportClient

struct FileImportClient {
  var importFile: @Sendable (_ from: URL, _ to: URL) async throws -> Void
  var importFileSync: @Sendable (_ from: URL, _ to: URL) throws -> Void
}

// MARK: DependencyKey

extension FileImportClient: DependencyKey {
  static var liveValue: Self {
    Self(
      importFile: { from, to in
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 16000
        options.bitDepth = 24
        options.channels = 1

        let converter = FormatConverter(inputURL: from, outputURL: to, options: options)
        try await converter.startAsync()
      },
      importFileSync: { from, to in
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 16000
        options.bitDepth = 24
        options.channels = 1
        options.isInterleaved = false

        let converter = FormatConverter(inputURL: from, outputURL: to, options: options)
        let semaphore = DispatchSemaphore(value: 0)
        var thrownError: Error?

        converter.start { error in
          if let error {
            thrownError = error
          }
          semaphore.signal()
        }

        semaphore.wait()

        if let error = thrownError {
          throw error
        }
      }
    )
  }
}

extension DependencyValues {
  var fileImport: FileImportClient {
    get { self[FileImportClient.self] }
    set { self[FileImportClient.self] = newValue }
  }
}

private extension FormatConverter {
  func startAsync() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      start { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }
}
