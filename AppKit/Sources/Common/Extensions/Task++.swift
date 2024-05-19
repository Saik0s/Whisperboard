import Foundation
import ComposableArchitecture

extension Task where Success == Never, Failure == Never {
  static func sleep(seconds: Double) async throws {
    let duration = UInt64(seconds * 1_000_000_000)
    try await Task.sleep(nanoseconds: duration)
  }
}

extension Task where Failure == Error {
  /// Performs an async task in a sync context and returns the result.
  ///
  /// - Note: This function blocks the thread until the given operation is finished. The caller is responsible for managing multithreading.
  static func synchronous(priority: TaskPriority? = nil, operation: @escaping @Sendable () async throws -> Success) -> Success {
    let semaphore = DispatchSemaphore(value: 0)
    let result: LockIsolated<Success?> = .init(nil)

    Task(priority: priority) {
      defer { semaphore.signal() }
      let operationResult = try await operation()
      result.setValue(operationResult)
      return operationResult
    }

    semaphore.wait()

    return result.value.required()
  }
}
