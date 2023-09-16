
import SwiftUI

// MARK: - DebouncingTaskViewModifier

struct DebouncingTaskViewModifier<ID: Equatable>: ViewModifier {
  let id: ID
  let priority: TaskPriority
  let seconds: Double
  let task: @Sendable ()
    async -> Void

  init(
    id: ID,
    priority: TaskPriority = .userInitiated,
    seconds: Double = 0,
    task: @Sendable @escaping () async -> Void
  ) {
    self.id = id
    self.priority = priority
    self.seconds = seconds
    self.task = task
  }

  func body(content: Content) -> some View {
    content.task(id: id, priority: priority) {
      do {
        if seconds > 0 {
          try await Task.sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
        }
        await task()
      } catch {
        // log(error) CancellationError
      }
    }
  }
}

extension View {
  func task(
    id: some Equatable,
    priority: TaskPriority = .userInitiated,
    seconds: Double = 0,
    task: @Sendable @escaping () async -> Void
  ) -> some View {
    modifier(
      DebouncingTaskViewModifier(
        id: id,
        priority: priority,
        seconds: seconds,
        task: task
      )
    )
  }
}
