import AppDevUtils
import BackgroundTasks
import Dependencies
import Foundation
import SwiftUI
import UIKit

// MARK: - BackgroundProcessingClient

struct BackgroundProcessingClient {
  var startTask: @Sendable (RecordingInfo.ID) async throws -> Void
  var removeAndCancelAllTasks: @Sendable () -> Void
  var registerBackgroundTask: @Sendable () -> Void
}

// MARK: DependencyKey

extension BackgroundProcessingClient: DependencyKey {
  static let liveValue: BackgroundProcessingClient = {
    let client = BackgroundProcessingClientImpl(longTask: .transcription)

    return BackgroundProcessingClient(
      startTask: { recordingId in
        try await client.startTask(recordingId)
      },
      removeAndCancelAllTasks: {
        client.removeAndCancelAllTasks()
      },
      registerBackgroundTask: {
        client.registerBackgroundTask()
      }
    )
  }()
}

extension DependencyValues {
  var backgroundProcessingClient: BackgroundProcessingClient {
    get { self[BackgroundProcessingClient.self] }
    set { self[BackgroundProcessingClient.self] = newValue }
  }
}

// MARK: - BackgroundProcessingClientError

enum BackgroundProcessingClientError: Error {
  case noTasksInQueue
  case alreadyExecutingTask
}

// MARK: - BackgroundProcessingClientImpl

final class BackgroundProcessingClientImpl<State: Codable> {
  typealias T = LongTask<State>

  private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
  private var backgroundTaskScheduled: Bool = false
  private var isExecutingTask: Bool = false

  private var taskQueue: [State] {
    get { UserDefaults.standard.decode(forKey: #function) ?? [] }
    set { UserDefaults.standard.encode(newValue, forKey: #function) }
  }

  private let longTask: T

  init(longTask: T) {
    self.longTask = longTask
  }

  func startTask(_ taskState: State) async throws {
    guard taskQueue.isEmpty else {
      throw BackgroundProcessingClientError.alreadyExecutingTask
    }
    log.debug("Adding task to queue: \(taskState)")
    taskQueue.append(taskState)
    try await executeNextTask()
  }

  func removeAndCancelAllTasks() {
    taskQueue.removeAll()
    resetBackgroundTask()
  }

  func registerBackgroundTask() {
    let isRegistered = BGTaskScheduler.shared.register(forTaskWithIdentifier: longTask.identifier, using: nil) { [weak self] task in
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
      log.error("Failed to register background task with identifier: \(longTask.identifier)")
    }

    if !taskQueue.isEmpty {
      Task {
        do {
          try await executeNextTask()
        } catch {
          log.error(error)
        }
      }
    }
  }

  // MARK: - Private

  private func executeNextTask() async throws {
    guard let taskState = taskQueue.first, !isExecutingTask else {
      log.warning("No tasks(\(taskQueue.count)) to execute or already executing a task(\(isExecutingTask))")
      throw BackgroundProcessingClientError.noTasksInQueue
    }

    isExecutingTask = true

    backgroundTaskID = await UIApplication.shared.beginBackgroundTask {
      self.endBackgroundTask()
    }
    scheduleBackgroundTask()

    do {
      try await longTask.performTask(taskState)
      if !taskQueue.isEmpty {
        taskQueue.removeFirst()
      }
      isExecutingTask = false
      try await taskCompleted()
    } catch {
      customAssertionFailure()
      log.error(error)
      taskFailed()
      throw error
    }
  }

  private func executeNextTaskWithoutScheduling() async throws {
    guard let taskState = taskQueue.first, !isExecutingTask else {
      log.warning("No tasks(\(taskQueue.count)) to execute or already executing a task(\(isExecutingTask))")
      throw BackgroundProcessingClientError.noTasksInQueue
    }

    isExecutingTask = true

    try await longTask.performTask(taskState)
    isExecutingTask = false
    try await executeNextTaskWithoutScheduling()
  }

  private func scheduleBackgroundTask() {
    assert(!backgroundTaskScheduled)

    let taskRequest = BGProcessingTaskRequest(identifier: longTask.identifier)
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

  private func taskCompleted() async throws {
    resetBackgroundTask()
    if !taskQueue.isEmpty {
      try await executeNextTask()
    }
  }

  private func taskFailed() {
    isExecutingTask = false
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
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: longTask.identifier)
    backgroundTaskScheduled = false
  }
}
