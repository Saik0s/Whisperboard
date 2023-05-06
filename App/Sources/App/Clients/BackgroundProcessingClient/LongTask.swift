import Foundation

// MARK: - LongTask

struct LongTask<State: Codable> {
  /// A string that uniquely identifies an instance of a type.
  ///
  /// - note: The identifier should be consistent and persistent across different executions of the program.
  let identifier: String
  /// Performs an asynchronous task based on the given state.
  ///
  /// - parameter state: The state that determines the task to be performed.
  /// - throws: An error if the task fails or is cancelled.
  /// - note: This function is marked with the `async` keyword, which means it can be called with the `await` expression.
  let performTask: (State) async throws -> Void
}
