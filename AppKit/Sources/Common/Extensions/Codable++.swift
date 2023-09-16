import Foundation

extension Decodable {
  static func fromFile(path: String, decoder: JSONDecoder = JSONDecoder()) throws -> Self {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try decoder.decode(Self.self, from: data)
  }
}

extension Encodable {
  func saveToFile(path: String, encoder: JSONEncoder = JSONEncoder()) throws {
    let data = try encoder.encode(self)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
  }
}
