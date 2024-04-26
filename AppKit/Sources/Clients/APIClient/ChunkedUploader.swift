import CryptoKit
import Foundation
import IdentifiedCollections

// MARK: - ChunkedUploader

class ChunkedUploader: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
  // MARK: - ChunkedUploaderError

  enum ChunkedUploaderError: Error {
    case fileHandleCreationFailed
    case fileReadError
    case uploadTaskCreationFailed
  }

  // MARK: - FileChunk

  struct FileChunk {
    let data: Data
    let index: Int
    let totalChunks: Int
    let originalFileName: String
  }

  // MARK: - UploadProgress

  struct UploadProgress: Identifiable {
    var id: Int { chunkIndex }

    let chunkIndex: Int
    let totalChunks: Int
    let progress: Double // Progress of the current chunk upload
  }

  // MARK: - UploadState

  enum UploadState {
    case uploading(progress: Double)
    case done(response: URLResponse, data: Data)
  }

  // MARK: - CustomHeaderFields

  enum CustomHeaderFields: String {
    case originalFilename = "X-Original-Filename"
    case chunkIndex = "X-Chunk-Index"
    case totalChunks = "X-Total-Chunks"
    case uploadID = "X-Upload-ID"
    case hash = "X-Hash"
  }

  actor ProgressContainer {
    private var progressPerFile: [String: IdentifiedArrayOf<UploadProgress>] = [:]
    private var continuations: [String: AsyncThrowingStream<UploadState, Error>.Continuation] = [:]

    func updateProgress(fileName: String, uploadProgress: UploadProgress) {
      var progresses = progressPerFile[fileName, default: []]
      progresses[id: uploadProgress.id] = uploadProgress
      progressPerFile[fileName] = progresses
    }

    func totalProgress(fileName: String) -> Double {
      guard let progresses = progressPerFile[fileName] else { return 0.0 }
      return progresses.reduce(0.0) { $0 + $1.progress / Double($1.totalChunks) }
    }

    func resetProgress(fileName: String) {
      progressPerFile[fileName] = nil
    }

    func setContinuation(fileName: String, continuation: AsyncThrowingStream<UploadState, Error>.Continuation?) {
      continuations[fileName] = continuation
    }

    func getContinuation(for fileName: String) -> AsyncThrowingStream<UploadState, Error>.Continuation? {
      continuations[fileName]
    }
  }

  private var backgroundSession: URLSession!
  private let progressContainer = ProgressContainer()

  override init() {
    super.init()
    let config = URLSessionConfiguration.default
    backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }

  func uploadFile(fileURL: URL, serverURL: URL, additionalHeaders: [String: String], chunkSize: Int) -> AsyncThrowingStream<UploadState, Error> {
    AsyncThrowingStream { continuation in
      logs.debug("Starting uploadFile function with fileURL: \(fileURL)")

      Task { [weak self] in
        guard let self else { return }

        do {
          await self.progressContainer.setContinuation(fileName: fileURL.lastPathComponent, continuation: continuation)
          logs.info("Continuation for \(fileURL.lastPathComponent) set")
          logs.info("Calculating hash for file at \(fileURL)")
          let hash = try hashFile(at: fileURL)
          let uploadID = UUID().uuidString
          logs.info("Generated uploadID: \(uploadID)")
          var additionalHeaders = additionalHeaders
          additionalHeaders[CustomHeaderFields.uploadID.rawValue] = uploadID
          additionalHeaders[CustomHeaderFields.hash.rawValue] = hash
          logs.info("Splitting file into chunks")
          let chunks = try await splitFileIntoChunks(fileURL: fileURL, chunkSize: chunkSize)
          logs.info("File split into \(chunks.count) chunks")
          for chunk in chunks {
            logs.info("Uploading chunk \(chunk.index) of \(chunk.totalChunks)")
            let (data, response) = try await uploadChunk(chunk: chunk, to: serverURL, additionalHeaders: additionalHeaders)
            if let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode != 200 {
              logs.error("Upload failed with status code \(httpURLResponse.statusCode)")
              logs.error("\(String(data: data, encoding: .utf8) ?? "No data")")
              continuation.finish(throwing: ChunkedUploaderError.uploadTaskCreationFailed)
              break
            }
            logs.info("Yielded upload progress for chunk \(chunk.index)")
            if chunk.index == chunk.totalChunks - 1 {
              continuation.yield(.done(response: response, data: data))
              continuation.finish()
              logs.info("Upload completed for file \(fileURL.lastPathComponent)")
            }
          }
          logs.info("Continuation for \(fileURL.lastPathComponent) finished")
        } catch {
          logs.error("Error occurred during file upload: \(error)")
          continuation.finish(throwing: error)
        }
        await self.progressContainer.resetProgress(fileName: fileURL.lastPathComponent)
        await self.progressContainer.setContinuation(fileName: fileURL.lastPathComponent, continuation: nil)
      }
    }
  }

  private func splitFileIntoChunks(fileURL: URL, chunkSize: Int) async throws -> [FileChunk] {
    logs.debug("Starting splitFileIntoChunks function with fileURL: \(fileURL), chunkSize: \(chunkSize)")
    guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
      logs.error("Failed to create file handle for \(fileURL)")
      throw ChunkedUploaderError.fileHandleCreationFailed
    }

    defer { try? fileHandle.close() }

    let fileSize = try fileHandle.seekToEnd()
    try fileHandle.seek(toOffset: 0)

    let totalChunks = Int(ceil(Double(fileSize) / Double(chunkSize)))
    var chunks = [FileChunk]()
    logs.info("File size: \(fileSize), total chunks: \(totalChunks)")

    for index in 0 ..< totalChunks {
      let nextChunkSize = min(chunkSize, Int(fileSize - fileHandle.offsetInFile))

      let chunkData = fileHandle.readData(ofLength: nextChunkSize)

      chunks.append(FileChunk(data: chunkData,
                              index: index,
                              totalChunks: totalChunks,
                              originalFileName: fileURL.lastPathComponent))
      logs.info("Chunk \(index) created")
    }

    logs.info("File split into \(chunks.count) chunks")
    return chunks
  }

  private func uploadChunk(
    chunk: FileChunk,
    to serverURL: URL,
    additionalHeaders: [String: String]
  ) async throws -> (Data, URLResponse) {
    logs.debug("Starting uploadChunk function with chunk index: \(chunk.index), serverURL: \(serverURL), additionalHeaders: \(additionalHeaders)")
    var request = URLRequest(url: serverURL)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Accept")

    // Set headers specific to the chunk being uploaded.
    request.addValue(chunk.originalFileName, forHTTPHeaderField: CustomHeaderFields.originalFilename.rawValue)
    request.addValue("\(chunk.index)", forHTTPHeaderField: CustomHeaderFields.chunkIndex.rawValue)
    request.addValue("\(chunk.totalChunks)", forHTTPHeaderField: CustomHeaderFields.totalChunks.rawValue)

    // Add any additional headers provided.
    for (key, value) in additionalHeaders {
      request.addValue(value, forHTTPHeaderField: key)
    }

    return try await backgroundSession.upload(for: request, from: chunk.data)
  }

  func urlSession(_: URLSession, task: URLSessionTask, didSendBodyData _: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    logs.debug(
      "urlSession function called with task: \(task), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSend: \(totalBytesExpectedToSend)"
    )
    Task.detached { [weak self] in
      if let httpTask = task as? URLSessionUploadTask, let request = httpTask.originalRequest,
         let fileName = request.value(forHTTPHeaderField: CustomHeaderFields.originalFilename.rawValue),
         let continuation = await self?.progressContainer.getContinuation(for: fileName) {
        // Calculate the progress of the current chunk.
        let progressValue = Double(totalBytesSent) / Double(totalBytesExpectedToSend)

        // Retrieve the current chunk index and total chunks from the HTTP headers.
        if let indexString = request.value(forHTTPHeaderField: CustomHeaderFields.chunkIndex.rawValue), let index = Int(indexString),
           let totalChunksString = request.value(forHTTPHeaderField: CustomHeaderFields.totalChunks.rawValue),
           let totalChunks = Int(totalChunksString) {
          let uploadProgress = UploadProgress(chunkIndex: index, totalChunks: totalChunks, progress: progressValue)
          await self?.progressContainer.updateProgress(fileName: fileName, uploadProgress: uploadProgress)
          let totalProgress = await self?.progressContainer.totalProgress(fileName: fileName) ?? 0.0

          continuation.yield(.uploading(progress: totalProgress))
          logs.info("Yielded upload progress for chunk \(index)")
        }
      } else {
        logs.error("Unable to find continuation for task \(task)")
      }
    }
  }
}

// MARK: - ChunkedUploader.ChunkedUploaderError + LocalizedError

extension ChunkedUploader.ChunkedUploaderError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .fileHandleCreationFailed:
      logs.error("File handle creation failed")
      return "Unable to open file for reading."
    case .fileReadError:
      logs.error("File read error occurred")
      return "An error occurred while reading the file."
    case .uploadTaskCreationFailed:
      logs.error("Upload task creation failed")
      return "Failed to create an upload task."
    }
  }
}

private func hashFile(at url: URL) throws -> String {
  logs.debug("Starting hashFile function with url: \(url)")
  let bufferSize = 1024 * 1024
  guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
    logs.error("Failed to create file handle for \(url)")
    throw ChunkedUploader.ChunkedUploaderError.fileHandleCreationFailed
  }
  defer { fileHandle.closeFile() }

  var hasher = SHA256()

  while autoreleasepool(invoking: {
    let data = fileHandle.readData(ofLength: bufferSize)
    if !data.isEmpty {
      hasher.update(data: data)
      logs.info("Updated hasher with data of length \(data.count)")
      return true // Continue
    } else {
      logs.info("No more data to read from file")
      return false // End
    }
  }) {}

  let digest = hasher.finalize()
  let hash = digest.map { String(format: "%02x", $0) }.joined()
  logs.info("Calculated hash: \(hash)")
  return hash
}
