import AppDevUtils
import BackgroundTasks
import Dependencies
import Foundation
import SwiftUI
import UIKit

// MARK: - BackgroundProcessingClient

struct BackgroundProcessingClient {
  var startTask: (RecordingInfo.ID) -> Void
  var removeAndCancelAllTasks: () -> Void
  var registerBackgroundTask: () -> Void
}

// MARK: DependencyKey

extension BackgroundProcessingClient: DependencyKey {
  static let liveValue: BackgroundProcessingClient = {
    let client = BackgroundProcessingClientImpl(longTask: .transcription)

    return BackgroundProcessingClient(
      startTask: { recordingId in
        client.startTask(recordingId)
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
  private var currentTask: Task<Void, Error>?

  init(longTask: T) {
    self.longTask = longTask
  }

  func startTask(_ taskState: State) {
    log.debug("Adding task to queue: \(taskState)")
    taskQueue.append(taskState)
    currentTask = Task {
      await executeNextTask()
    }
  }

  func removeAndCancelAllTasks() {
    currentTask?.cancel()
    currentTask = nil
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
        await executeNextTask()
      }
    }
  }

  // MARK: - Private

  private func executeNextTask() async {
    guard let taskState = taskQueue.first, !isExecutingTask else {
      log.info("No tasks(\(taskQueue.count)) to execute or already executing a task(\(isExecutingTask))")
      return
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
      await taskCompleted()
    } catch {
      customAssertionFailure()
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

  private func taskCompleted() async {
    resetBackgroundTask()
    if !taskQueue.isEmpty {
      await executeNextTask()
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
    if backgroundTaskScheduled {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: longTask.identifier)
      backgroundTaskScheduled = false
    }
  }
}
