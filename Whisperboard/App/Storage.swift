//
// Created by Igor Tarasenko on 24/12/2022.
//

import Foundation

struct Recording: Identifiable, Codable, Hashable {
  var id: URL { fileURL }
  let fileURL: URL
  let text: String
}

final class Storage {
  var recordings: [Recording] {
    get {
      guard let data = UserDefaults.standard.object(forKey: #function) as? Data else { return [] }
      do {
        return try JSONDecoder().decode([Recording].self, from: data)
      } catch {
        log(error)
        return []
      }
    }
    set {
      do {
        let data = try JSONEncoder().encode(newValue)
        UserDefaults.standard.set(data, forKey: #function)
      } catch {
        log(error)
      }
    }
  }
}
