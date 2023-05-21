import Foundation

let semaphore = DispatchSemaphore(value: 0)

let baseURL = "https://saik0s--whisperboard-webapp-whisperboard-webapp.modal.run"

func sendFile(fileUrl: String) {
  let url = URL(string: "\(baseURL)/transcribe")!
  var request = URLRequest(url: url)
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")
  request.httpMethod = "POST"

  let fileData = try! Data(contentsOf: URL(fileURLWithPath: fileUrl))
  let base64FileData = fileData.base64EncodedString()

  let data = ["file_string": base64FileData, "filename": "test.mp3"]
  let jsonData = try! JSONSerialization.data(withJSONObject: data, options: [])

  request.httpBody = jsonData

  URLSession.shared.dataTask(with: request) { (data, response, error) in
      if let error = error {
        print("Error: \(error)")
      } else if let data = data {
        do {
          if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
             let callId = json["call_id"] as? String {
            fetchResult(callId: callId)
          }
        } catch {
          print("Error: \(error)")
        }
      }
      semaphore.signal()
    }.resume()

  semaphore.wait()
}

func fetchResult(callId: String) {
  let url = URL(string: "\(baseURL)/result/\(callId)")!
  var request = URLRequest(url: url)
  request.httpMethod = "GET"

  var isFinished = false
  while !isFinished {
    URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
          print("Error: \(error)")
        } else if let response = response as? HTTPURLResponse, response.statusCode == 200,
                  let data = data {
          do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            print(json)
            isFinished = true
          } catch {
            print("Error: \(error)")
          }
        }
        semaphore.signal()
      }.resume()

    semaphore.wait()
    sleep(1)
  }
}

sendFile(fileUrl: "path/to/test.mp3")
