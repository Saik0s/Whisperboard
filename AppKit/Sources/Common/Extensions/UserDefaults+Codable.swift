import Foundation

extension UserDefaults {
  func decode<T: Decodable>(forKey: String) -> T? {
    guard let data = data(forKey: forKey) else {
      logs.error("No data for key: \(forKey)")
      return nil
    }

    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      logs.error("Error decoding data for key: \(forKey)")
      return nil
    }
  }

  func encode(_ value: (some Encodable)?, forKey: String) {
    guard let value else {
      set(nil, forKey: forKey)
      return
    }

    do {
      let data = try JSONEncoder().encode(value)
      set(data, forKey: forKey)
    } catch {
      logs.error("Error encoding data for key: \(forKey)")
    }
  }
}
