import Foundation

extension Decodable {
  init(fromFile url: URL, decoder: JSONDecoder = JSONDecoder()) throws {
    let data = try Data(contentsOf: url)
    self = try decoder.decode(Self.self, from: data)
  }
}

extension Encodable {
  func write(toFile url: URL, encoder: JSONEncoder = JSONEncoder()) throws {
    let data = try encoder.encode(self)
    try data.write(to: url)
  }
}
