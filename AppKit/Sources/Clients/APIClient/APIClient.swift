import Dependencies
import Foundation

// MARK: - APIClientError

enum APIClientError: Error {
  case uploadFailed
  case resultFailed
  case resultNotReady
  case resultErrorMessage(String)
}

// MARK: - UploadResponse

struct UploadResponse: Codable {
  let id: String
}

// MARK: - ResultResponse

struct ResultResponse: Codable {
  let transcription: RemoteTranscription?
  let isDone: Bool
}

struct RemoteTranscription: Codable {
  struct Segment: Codable {
    let text: String
    let start: Double
    let end: Double
  }
  let segments: [Segment]
  let language: String
}

// MARK: - APIClient

struct APIClient {
  var uploadRecordingAt: @Sendable (_ fileURL: URL) async throws -> UploadResponse
  var getTranscriptionResultFor: @Sendable (_ id: String) async throws -> ResultResponse
}

// MARK: DependencyKey

extension APIClient: DependencyKey {
  static var liveValue: APIClient {
    @Sendable
    func addHeaders(to request: inout URLRequest) {
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
        let url = try URL(string: Secrets.BACKEND_URL + "/stream").require()
        let dataToUpload = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let stream = InputStream(data: dataToUpload)

        var request = URLRequest(url: url)
        addHeaders(to: &request)
        request.httpMethod = "POST"
        request.addValue(fileName, forHTTPHeaderField: "X-File-Name")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue(String(dataToUpload.count), forHTTPHeaderField: "Content-Length")
        log.verbose(request.cURL(pretty: true))

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
        let resultURL = try URL(string: Secrets.BACKEND_URL + "/result/\(id)").require()
        var request = URLRequest(url: resultURL)
        addHeaders(to: &request)
        request.httpMethod = "GET"

        log.verbose(request.cURL(pretty: true))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
          throw APIClientError.resultFailed
        }

        log.verbose(httpResponse)
        log.verbose(String(data: data, encoding: .utf8) ?? "No data")

        switch httpResponse.statusCode {
        case 200:
          let transcription = try JSONDecoder().decode(RemoteTranscription.self, from: data)
          return ResultResponse(transcription: transcription, isDone: true)
        case 202:
          return ResultResponse(transcription: nil, isDone: false)
        case 500:
          let message = String(data: data, encoding: .utf8) ?? "Unknown error"
          throw APIClientError.resultErrorMessage(message)
        default:
          throw APIClientError.resultFailed
        }
      }
    )
  }
}

// MARK: - UploadDelegate

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
    _: URLSession,
    task _: URLSessionTask,
    didSendBodyData _: Int64,
    totalBytesSent _: Int64,
    totalBytesExpectedToSend _: Int64
  ) {}

  func urlSession(_: URLSession, needNewBodyStreamForTask task: URLSessionTask) async -> InputStream? {
    log.debug("needNewBodyStreamForTask")
    guard let stream = streams[task.taskIdentifier] else {
      log.error("No stream for task \(task.taskIdentifier)")
      return nil
    }
    return stream
  }

  func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    log.debug("didCompleteWithError")
    if let error {
      log.error(error)
      taskCompletions[task.taskIdentifier]?.resume(throwing: error)
    }
  }

  func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
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
