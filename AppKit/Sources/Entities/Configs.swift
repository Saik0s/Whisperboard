import Foundation

enum Configs {
  static let logFileURL: URL = {
    let fileName = "log-\(Date().formatted(date: .numeric, time: .omitted).onlyDigitsAndPlus).log"
    return FileManager.default.temporaryDirectory.appending(component: fileName)
  }()
}
