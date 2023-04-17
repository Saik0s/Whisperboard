import AppDevUtils
import BackgroundTasks
import Foundation
import SwiftUI
import UIKit

// MARK: - BackgroundProcessingClient

///
/// let task = LongTask<Int>(identifier: "com.example.task") { state in
///   // Perform the long task
/// }
/// let processingClient = BackgroundProcessingClient(task: task)
/// processingClient.startTask(0)
///
@MainActor
final class BackgroundProcessingClient<State: Codable> {
  typealias T = LongTask<State>

  private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
  private var backgroundTaskScheduled: Bool = false
  private var isExecutingTask: Bool = false

  private var taskQueue: [State] {
    get { UserDefaults.standard.decode(forKey: #function) ?? [] }
    set { UserDefaults.standard.encode(newValue, forKey: #function) }
  }

  private let task: T

  init(task: T) {
    self.task = task
    registerBackgroundTask()
  }

  func startTask(_ taskState: State) {
    taskQueue.append(taskState)
    Task {
      await executeNextTask()
    }
  }

  func removeAndCancelAllTasks() {
    taskQueue.removeAll()
    resetBackgroundTask()
  }

  // MARK: - Private

  private func registerBackgroundTask() {
    let isRegistered = BGTaskScheduler.shared.register(forTaskWithIdentifier: task.identifier, using: nil) { [weak self] task in
      guard let self else {
        task.setTaskCompleted(success: false)
        return
      }

      task.expirationHandler = {
        task.setTaskCompleted(success: false)
      }

      Task {
        do {
          try await self.executeNextTaskWithoutScheduling()
          task.setTaskCompleted(success: true)
        } catch {
          log.error(error)
          task.setTaskCompleted(success: false)
        }
      }
    }

    if isRegistered {
      log.info("Background task registered")
    } else {
      log.error("Failed to register background task with identifier: \(task.identifier)")
    }
  }

  private func executeNextTask() async {
    guard let taskState = taskQueue.first, !isExecutingTask else {
      log.info("No tasks(\(taskQueue.count)) to execute or already executing a task(\(isExecutingTask))")
      return
    }

    isExecutingTask = true

    backgroundTaskID = UIApplication.shared.beginBackgroundTask {
      self.endBackgroundTask()
    }

    scheduleBackgroundTask()
    do {
      try await task.performTask(taskState)
      await taskCompleted()
    } catch {
      log.error(error)
      taskFailed()
    }
  }

  private func executeNextTaskWithoutScheduling() async throws {
    guard let taskState = taskQueue.first, !isExecutingTask else {
      log.info("No tasks(\(taskQueue.count)) to execute or already executing a task(\(isExecutingTask))")
      return
    }

    isExecutingTask = true

    try await task.performTask(taskState)
    try await executeNextTaskWithoutScheduling()
  }

  private func scheduleBackgroundTask() {
    assert(!backgroundTaskScheduled)

    let taskRequest = BGProcessingTaskRequest(identifier: task.identifier)
    taskRequest.requiresNetworkConnectivity = false
    taskRequest.requiresExternalPower = false
    taskRequest.earliestBeginDate = Date(timeIntervalSinceNow: 1)

    do {
      try BGTaskScheduler.shared.submit(taskRequest)
      backgroundTaskScheduled = true
    } catch {
      log.error("Failed to schedule background task: \(error)")
      backgroundTaskScheduled = false
    }
  }

  private func taskCompleted() async {
    resetBackgroundTask()
    await executeNextTask()
  }

  private func taskFailed() {
    resetBackgroundTask()
  }

  private func resetBackgroundTask() {
    endBackgroundTask()
    removeScheduledBackgroundTask()
  }

  private func endBackgroundTask() {
    UIApplication.shared.endBackgroundTask(backgroundTaskID)
    backgroundTaskID = .invalid
  }

  private func removeScheduledBackgroundTask() {
    if backgroundTaskScheduled {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: task.identifier)
      backgroundTaskScheduled = false
    }
  }
}
