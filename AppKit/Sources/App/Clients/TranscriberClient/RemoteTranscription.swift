import AppDevUtils
import DeviceCheck
import Foundation

// MARK: - SendError

enum SendError: Error, LocalizedError {
  case failedToSend

  public var errorDescription: String? {
    switch self {
    case .failedToSend: return "Failed to send file"
    }
  }
}

func sendFile(fileUrl: URL) async throws -> String {
  log.verbose("Sending file \(fileUrl)")
  let url = try URL(string: "\(Secrets.BACKEND_URL)").require().appendingPathComponent("transcribe")
  var request = URLRequest(url: url)
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")
  request.addValue(Secrets.API_KEY, forHTTPHeaderField: "Authorization")
  let device_identifier = await getDeviceIdentifier()
  request.addValue(device_identifier, forHTTPHeaderField: "x-device-identifier")
  request.httpMethod = "POST"

  let fileData = try Data(contentsOf: fileUrl)
  let base64FileData = fileData.base64EncodedString()

  let body = ["file_string": base64FileData, "filename": fileUrl.lastPathComponent]
  let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

  request.httpBody = jsonData

  let (data, _) = try await URLSession.shared.data(for: request)

  log.verbose(data.utf8String)

  if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
     let callId = json["call_id"] as? String {
    log.verbose("Call ID: \(callId)")
    return callId
  }

  throw SendError.failedToSend
}

// MARK: - FetchError

enum FetchError: Error, LocalizedError {
  case invalidStatus(Int, Data)

  public var errorDescription: String? {
    switch self {
    case let .invalidStatus(_, data): return data.utf8String
    }
  }
}

func waitForResults<Result: Codable>(callId: String) async throws -> Result {
  let url = try URL(string: "\(Secrets.BACKEND_URL)").require().appendingPathComponent("result").appendingPathComponent(callId)
  var request = URLRequest(url: url)
  request.addValue(Secrets.API_KEY, forHTTPHeaderField: "Authorization")
  let device_identifier = await getDeviceIdentifier()
  request.addValue(device_identifier, forHTTPHeaderField: "x-device-identifier")
  request.httpMethod = "GET"

  var isFinished = false
  while !isFinished {
    let (data, response) = try await URLSession.shared.data(for: request)

    if let response = response as? HTTPURLResponse {
      if response.statusCode == 200 {
        log.debug(data.utf8String)
        isFinished = true

        let decoder = JSONDecoder()
        let result = try decoder.decode(Result.self, from: data)
        return result
      } else if response.statusCode == 202 {
        log.verbose("Still processing \(callId)...")
      } else {
        throw FetchError.invalidStatus(response.statusCode, data)
      }
    }

    sleep(1)
  }
}

private func getDeviceIdentifier() async -> String {
  do {
    return try await DCDevice.current.generateToken().utf8String
  } catch {
    log.error(error)
    if let device_identifier = UserDefaults.standard.string(forKey: "device_identifier") {
      return device_identifier
    } else {
      let device_identifier = UUID().uuidString
      UserDefaults.standard.set(device_identifier, forKey: "device_identifier")
      return device_identifier
    }
  }
}
