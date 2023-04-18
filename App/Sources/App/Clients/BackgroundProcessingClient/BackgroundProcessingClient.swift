import AppDevUtils
import BackgroundTasks
import Dependencies
import Foundation
import SwiftUI
import UIKit

// MARK: - BackgroundProcessingClient

@MainActor
struct BackgroundProcessingClient {
  var startTask: (RecordingInfo.ID) -> Void
  var removeAndCancelAllTasks: () -> Void
  var registerBackgroundTask: () -> Void
}

// MARK: DependencyKey

extension BackgroundProcessingClient: DependencyKey {
  static let liveValue: BackgroundProcessingClient = {
    let client = BackgroundProcessingClientImpl(task: .transcription)

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

@MainActor
final class BackgroundProcessingClientImpl<State: Codable> {
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

  func registerBackgroundTask() {
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

  // MARK: - Private

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
      isExecutingTask = false
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
    isExecutingTask = false
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
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: task.identifier)
      backgroundTaskScheduled = false
    }
  }
}
