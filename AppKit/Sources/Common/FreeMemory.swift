import Foundation
import os
import OSLog

func freeMemoryAmount() -> UInt64 {
  #if targetEnvironment(simulator)
    return availableMemory()
  #else
    let size = os_proc_available_memory()
    return UInt64(size)
  #endif
}

func availableMemory() -> UInt64 {
  let processInfo = ProcessInfo.processInfo
  let memory = processInfo.physicalMemory
  return memory
}

func bytesToReadableString(bytes: UInt64) -> String {
  let formatter = ByteCountFormatter()
  formatter.allowedUnits = [.useAll]
  formatter.countStyle = .memory
  return formatter.string(fromByteCount: Int64(bytes))
}

extension UInt64 {
  var readableString: String {
    bytesToReadableString(bytes: self)
  }
}
