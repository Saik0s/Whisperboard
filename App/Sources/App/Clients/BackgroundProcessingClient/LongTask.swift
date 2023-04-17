import Foundation

// MARK: - LongTask

struct LongTask<State: Codable> {
  let identifier: String
  let performTask: (State) async throws -> Void
}
