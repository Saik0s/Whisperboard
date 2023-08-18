import Foundation

extension URL {
  func isDirectoryAndReachable() throws -> Bool {
    guard try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
      return false
    }
    return try checkResourceIsReachable()
  }

  func directoryTotalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
    guard try isDirectoryAndReachable() else { return nil }
    if includingSubfolders {
      guard let urls = FileManager.default.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return nil }
      return try urls.lazy.reduce(0) {
        try ($1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0) + $0
      }
    }
    return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil).lazy.reduce(0) {
      try ($1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        .totalFileAllocatedSize ?? 0) + $0
    }
  }
}
