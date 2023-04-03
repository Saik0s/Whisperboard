import AppDevUtils
import Dependencies
import Foundation

// MARK: - DiskSpaceClient

struct DiskSpaceClient {
  var freeSpace: () -> UInt64
  var totalSpace: () -> UInt64
  var takenSpace: () -> UInt64
  var deleteStorage: () async throws -> Void
}

// MARK: DependencyKey

extension DiskSpaceClient: DependencyKey {
  static var liveValue: Self {
    Self(
      freeSpace: { freeDiskSpaceInBytes() },
      totalSpace: { totalDiskSpaceInBytes() },
      takenSpace: { takenSpace() },
      deleteStorage: { try await deleteStorage() }
    )
  }

  static func totalDiskSpaceInBytes() -> UInt64 {
    do {
      let fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
      let capacity = values.volumeAvailableCapacityForImportantUsage
      return UInt64(capacity ?? 0)
    } catch {
      log.error("Error while getting total disk space: \(error)")
      return 0
    }
  }

  static func freeDiskSpaceInBytes() -> UInt64 {
    do {
      let fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      let capacity = values.volumeAvailableCapacityForImportantUsage
      return UInt64(capacity ?? 0)
    } catch {
      log.error("Error while getting free disk space: \(error)")
      return 0
    }
  }

  static func takenSpace() -> UInt64 {
    do {
      let fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let capacity = try fileURL.directoryTotalAllocatedSize(includingSubfolders: true)
      return UInt64(capacity ?? 0)
    } catch {
      log.error("Error while getting taken disk space: \(error)")
      return 0
    }
  }

  static func deleteStorage() async throws {
    let fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    try FileManager.default.removeItem(at: fileURL)
  }
}

extension DependencyValues {
  var diskSpace: DiskSpaceClient {
    get { self[DiskSpaceClient.self] }
    set { self[DiskSpaceClient.self] = newValue }
  }
}

extension URL {
  /// check if the URL is a directory and if it is reachable
  func isDirectoryAndReachable() throws -> Bool {
    guard try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
      return false
    }
    return try checkResourceIsReachable()
  }

  /// returns total allocated size of a the directory including its subFolders or not
  func directoryTotalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
    guard try isDirectoryAndReachable() else { return nil }
    if includingSubfolders {
      guard let urls = FileManager.default.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return nil }
      return try urls.lazy.reduce(0) {
        (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0) + $0
      }
    }
    return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil).lazy.reduce(0) {
      (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        .totalFileAllocatedSize ?? 0) + $0
    }
  }
}
