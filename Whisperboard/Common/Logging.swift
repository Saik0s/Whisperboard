//
// Created by Igor Tarasenko on 24/12/2022.
//

import Foundation

private let rootFolderName = "Whisperboard"
private func relativeToRootPath(from path: String) -> String {
  path.split(separator: "/").drop { $0 != rootFolderName }.dropFirst().joined(separator: "/")
}

func log(_ items: Any..., file: StaticString = #filePath, line: UInt = #line, function: StaticString = #function) {
  let joinedItems = items.map(String.init(describing:)).joined(separator: " ")
  print("\(relativeToRootPath(from: "\(file)")):\(line) \(function): \(joinedItems)")
}
