import Foundation

extension Decodable {
  init(fromFile url: URL, decoder: JSONDecoder = JSONDecoder()) throws {
    let data = try Data(contentsOf: url)
    self = try decoder.decode(Self.self, from: data)
  }

  static func fromFile(path: String, decoder: JSONDecoder = JSONDecoder()) throws -> Self {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try decoder.decode(Self.self, from: data)
  }
}

extension Encodable {
  func saveToFile(at url: URL, encoder: JSONEncoder = JSONEncoder()) throws {
    let data = try encoder.encode(self)
    try data.write(to: url)
  }
}
