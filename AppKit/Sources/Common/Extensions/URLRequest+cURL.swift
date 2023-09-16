import Foundation

extension URLRequest {
  func cURL(pretty: Bool = false) -> String {
    let newLine = pretty ? "\\\n" : ""
    let method = (pretty ? "--request " : "-X ") + "\(httpMethod ?? "GET") \(newLine)"
    let url: String = (pretty ? "--url " : "") + "\'\(url?.absoluteString ?? "")\' \(newLine)"

    var cURL = "curl "
    var header = ""
    var data = ""

    if let httpHeaders = allHTTPHeaderFields, httpHeaders.keys.isEmpty == false {
      for (key, value) in httpHeaders {
        header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
      }
    }

    if let bodyData = httpBody, let bodyString = String(data: bodyData, encoding: .utf8), !bodyString.isEmpty {
      data = "--data '\(bodyString)'"
    }

    cURL += method + url + header + data

    return cURL
  }
}
