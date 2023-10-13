import Dependencies
import Foundation

// MARK: - APIClientError

enum APIClientError: Error {
  case uploadFailed
  case resultFailed
}

// MARK: - UploadResponse

struct UploadResponse: Codable {
  let id: String
}

// MARK: - ResultResponse

struct ResultResponse: Codable {
  let transcription: String
  let isDone: Bool
}

// MARK: - APIClient

struct APIClient {
  var uploadRecordingAt: @Sendable (_ fileURL: URL) async throws -> UploadResponse
  var getTranscriptionResultFor: @Sendable (_ id: String) async throws -> ResultResponse
}

// MARK: DependencyKey

extension APIClient: DependencyKey {
  static var liveValue: APIClient {
    @Sendable func addHeaders(to request: inout URLRequest) {
      @Dependency(\.keychainClient) var keychainClient: KeychainClient
      request.addValue("application/json", forHTTPHeaderField: "Accept")
      request.addValue(keychainClient.userID, forHTTPHeaderField: "X-User-ID")
      request.addValue(Secrets.API_KEY, forHTTPHeaderField: "X-API-Key")
    }

    let sessionDelegate = UploadDelegate()
    let backgroundSession = URLSession(
      configuration: .background(withIdentifier: "me.igortarasenko.whisperboard.apiclient")
        .then { $0.isDiscretionary = false },
      delegate: sessionDelegate,
      delegateQueue: nil
    )

    return APIClient(
      uploadRecordingAt: { fileURL in
        let url = URL(string: Secrets.BACKEND_URL + "/stream")!
        let dataToUpload = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let stream = InputStream(data: dataToUpload)

        var request = URLRequest(url: url)
        addHeaders(to: &request)
        request.httpMethod = "POST"
        request.addValue(fileName, forHTTPHeaderField: "X-File-Name")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue(String(dataToUpload.count), forHTTPHeaderField: "Content-Length")
        let task = backgroundSession.uploadTask(withStreamedRequest: request)
        sessionDelegate.addStream(stream, for: task)
        task.resume()

        let (response, data) = try await sessionDelegate.waitForTask(task)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
          throw APIClientError.uploadFailed
        }

        return try JSONDecoder().decode(UploadResponse.self, from: data)
      },
      getTranscriptionResultFor: { id in
        let resultURL = URL(string: Secrets.BACKEND_URL + "/result/\(id)")!
        var request = URLRequest(url: resultURL)
        addHeaders(to: &request)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
          throw APIClientError.resultFailed
        }

        return try JSONDecoder().decode(ResultResponse.self, from: data)
      }
    )
  }
}

class UploadDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDelegate {
  private var streams: [Int: InputStream] = [:]
  private var taskCompletions: [Int: UnsafeContinuation<(URLResponse?, Data), Error>] = [:]

  func addStream(_ stream: InputStream, for task: URLSessionTask) {
    streams[task.taskIdentifier] = stream
  }

  func waitForTask(_ task: URLSessionTask) async throws -> (URLResponse?, Data) {
    try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<(URLResponse?, Data), Error>) in
      taskCompletions[task.taskIdentifier] = continuation
    }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {}

  func urlSession(_ session: URLSession, needNewBodyStreamForTask task: URLSessionTask) async -> InputStream? {
    log.debug("needNewBodyStreamForTask")
    guard let stream = streams[task.taskIdentifier] else {
      log.error("No stream for task \(task.taskIdentifier)")
      return nil
    }
    return stream
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    log.debug("didCompleteWithError")
    if let error = error {
      log.error(error)
      taskCompletions[task.taskIdentifier]?.resume(throwing: error)
    }
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    log.debug("didReceive data")
    streams[dataTask.taskIdentifier]?.close()
    taskCompletions[dataTask.taskIdentifier]?.resume(returning: (dataTask.response, data))
  }
}

extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClient.self] }
    set { self[APIClient.self] = newValue }
  }
}
