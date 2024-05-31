import Dependencies
import Foundation

// MARK: - APIClient

struct APIClient {
  // MARK: - APIClientError

  enum APIClientError: Error, LocalizedError {
    case uploadFailed
    case resultFailed
    case resultNotReady
    case resultErrorMessage(String)

    var errorDescription: String? {
      switch self {
      case .uploadFailed:
        "Failed to upload recording"
      case .resultFailed:
        "Failed to get transcription result"
      case .resultNotReady:
        "Transcription result is not ready yet"
      case let .resultErrorMessage(message):
        message
      }
    }
  }

  // MARK: - UploadResponse

  struct UploadResponse: Codable {
    let id: String
  }

  enum RecordingUploadProgress {
    case uploading(progress: Double)
    case done(response: UploadResponse)
  }

  // MARK: - ResultResponse

  struct ResultResponse: Codable {
    let transcription: RemoteTranscription?
    let isDone: Bool
  }

  // MARK: - RemoteTranscription

  struct RemoteTranscription: Codable {
    struct Segment: Codable {
      let text: String
      let start: Double
      let end: Double
    }

    let segments: [Segment]
    let language: String
  }

  var uploadRecordingAt: @Sendable (_ fileURL: URL) -> AsyncThrowingStream<RecordingUploadProgress, Error>
  var getTranscriptionResultFor: @Sendable (_ id: String) async throws -> ResultResponse
}

// MARK: DependencyKey

extension APIClient: DependencyKey {
  // MARK: - CustomHeaderFields

  enum CustomHeaderFields: String {
    case accept = "Accept"
    case userID = "X-User-ID"
    case apiKey = "X-API-Key"
  }

  static var liveValue: APIClient {
    @Dependency(\.keychainClient) var keychainClient: KeychainClient

    let chunkedUploader = ChunkedUploader()
    let additionalHeaders = [
      CustomHeaderFields.accept.rawValue: "application/json",
      CustomHeaderFields.userID.rawValue: keychainClient.userID,
      CustomHeaderFields.apiKey.rawValue: Secrets.API_KEY,
    ]

    return APIClient(
      uploadRecordingAt: { fileURL in
        AsyncThrowingStream { continuation in
          Task {
            do {
              let uploadResponse = try chunkedUploader.uploadFile(
                fileURL: fileURL,
                serverURL: URL(string: Secrets.BACKEND_URL + "/upload").require(),
                additionalHeaders: additionalHeaders,
                chunkSize: 10 * 1024 * 1024
              )

              for try await progress in uploadResponse {
                switch progress {
                case let .uploading(progress):
                  continuation.yield(.uploading(progress: progress))

                case let .done(response, data):
                  logs.info("\(response)")
                  logs.info("\(String(data: data, encoding: .utf8) ?? "No data")")
                  guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continuation.finish(throwing: APIClientError.uploadFailed)
                    return
                  }
                  try continuation.yield(.done(response: JSONDecoder().decode(UploadResponse.self, from: data)))
                  continuation.finish()
                }
              }
            } catch {
              continuation.finish(throwing: error)
            }
          }
        }
      },
      getTranscriptionResultFor: { id in
        let resultURL = try URL(string: Secrets.BACKEND_URL + "/result/\(id)").require()
        var request = URLRequest(url: resultURL)
        request.httpMethod = "GET"
        for (key, value) in additionalHeaders {
          request.addValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
          logs.info("\(request.cURL(pretty: true))")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
          throw APIClientError.resultFailed
        }

        logs.info("\(httpResponse)")
        logs.info("\(String(data: data, encoding: .utf8) ?? "No data")")

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

extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClient.self] }
    set { self[APIClient.self] = newValue }
  }
}
