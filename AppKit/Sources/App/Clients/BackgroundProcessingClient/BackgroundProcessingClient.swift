import AppDevUtils
import BackgroundTasks
import Dependencies
import Foundation
import SwiftUI
import UIKit

// MARK: - BackgroundProcessingClient

struct BackgroundProcessingClient {
  /// Starts a task for the given recording ID.
  ///
  /// - parameter id: The ID of the recording to start a task for.
  /// - throws: An error if the task cannot be started or completed.
  /// - note: This function is marked with `@Sendable` to indicate that it can be safely called from any actor or
  /// nonisolated context.
  var startTask: @Sendable (RecordingInfo.ID) async throws -> Void
  /// Cancels all the tasks in the queue and removes them.
  ///
  /// This function is marked as `@Sendable` to allow it to be called from any actor or nonisolated context.
  ///
  /// - note: This function does not wait for the tasks to finish before returning.
  var removeAndCancelAllTasks: @Sendable () -> Void
  /// Registers a background task to run when the app is in the background.
  ///
  /// This function is marked with the `@Sendable` attribute, which means it can be safely passed across actors or
  /// closures that are potentially executed on different threads.
  ///
  /// - note: The app must request permission to run background tasks by adding the `UIBackgroundModes` key to its
  /// Info.plist file.
  var registerBackgroundTask: @Sendable () -> Void
}

// MARK: DependencyKey

extension BackgroundProcessingClient: DependencyKey {
  /// Returns a singleton instance of `BackgroundProcessingClient` for transcription tasks.
  ///
  /// - note: The instance is created using a `BackgroundProcessingClientImpl` with a `.transcription` long task.
  /// - returns: A `BackgroundProcessingClient` that can start, cancel and register background tasks for transcription.
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
  /// A computed property that accesses or sets the `BackgroundProcessingClient` instance associated with the current
  /// environment.
  ///
  /// - get: Returns the `BackgroundProcessingClient` instance stored in the environment.
  /// - set: Stores a new `BackgroundProcessingClient` instance in the environment.
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

  /// A property that stores the identifier of a background task.
  ///
  /// - note: The value of this property is `.invalid` by default, and should be updated when a background task is started
  /// or ended.
  private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
  /// A Boolean value indicating whether a background task is scheduled.
  ///
  /// This property is used to track the state of the app's background activity. It is set to `true` when the app requests
  /// a background task identifier from the system, and set to `false` when the app invalidates the identifier or receives
  /// a `UIApplication.didEnterBackgroundNotification` notification.
  private var backgroundTaskScheduled: Bool = false
  /// A Boolean value indicating whether a task is currently executing.
  ///
  /// This property is `true` when a task is in progress and `false` otherwise.
  private var isExecutingTask: Bool = false

  /// A computed property that stores and retrieves an array of `State` values from `UserDefaults`.
  ///
  /// - get: Decodes the array of `State` values from `UserDefaults` for the key `#function`, or returns an empty array if
  /// the key is not found.
  /// - set: Encodes the new array of `State` values and stores it in `UserDefaults` for the key `#function`.
  private var taskQueue: [State] {
    get { UserDefaults.standard.decode(forKey: #function) ?? [] }
    set { UserDefaults.standard.encode(newValue, forKey: #function) }
  }

  /// A property that holds a long-running task of type `T`.
  ///
  /// - note: This property is private and should not be accessed directly. Use the `performLongTask` method instead.
  private let longTask: T

  /// Initializes an instance with a long-running task.
  ///
  /// - parameter longTask: The task that will be executed asynchronously.
  /// - note: The task must conform to the `LongTask` protocol.
  init(longTask: T) {
    self.longTask = longTask
  }

  /// Starts a task with the given state and executes it asynchronously.
  ///
  /// - parameter taskState: The state of the task to be executed.
  /// - throws: A `BackgroundProcessingClientError` if there is already a task in the queue.
  /// - note: This function appends the task to the queue and calls `executeNextTask()` to run it.
  func startTask(_ taskState: State) async throws {
    guard taskQueue.isEmpty else {
      throw BackgroundProcessingClientError.alreadyExecutingTask
    }
    log.debug("Adding task to queue: \(taskState)")
    taskQueue.append(taskState)
    try await executeNextTask()
  }

  /// Removes all tasks from the queue and cancels the background task.
  ///
  /// This function clears the `taskQueue` array and calls `resetBackgroundTask()` to cancel any pending or running
  /// background task. It should be called when the app is terminated or suspended.
  func removeAndCancelAllTasks() {
    taskQueue.removeAll()
    resetBackgroundTask()
  }

  /// Registers a background task with the system scheduler and executes the next task in the queue.
  ///
  /// - note: This function should be called only when the app is in the foreground and has tasks to perform in the
  /// background. If the task queue is empty, this function will remove and cancel all previously registered tasks.
  ///
  /// This function uses the `BGTaskScheduler` to register a task with a given identifier and a closure that runs when the
  /// system triggers the task. The closure uses a weak reference to `self` to avoid retain cycles and captures the
  /// current task in a `Task` object. The closure also sets an expiration handler that completes the task with a failure
  /// if it runs out of time. The `Task` object then awaits the execution of the next task in the queue without scheduling
  /// another background task. If the execution succeeds, the closure completes the task with a success; otherwise, it
  /// logs the error and completes the task with a failure.
  ///
  /// If the registration fails, this function logs an error message with the task identifier. If the task queue is not
  /// empty, this function removes and cancels all previously registered tasks to avoid conflicts or duplicates.
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
      removeAndCancelAllTasks()
    }
  }

  // MARK: - Private

  /// Executes the next task in the queue asynchronously and handles errors.
  ///
  /// - precondition: The task queue is not empty and no other task is being executed.
  /// - postcondition: The task queue is updated and the background task is ended.
  ///
  /// This function checks if there is a task in the queue and if it is not already executing a task. If so, it begins a
  /// background task and schedules another one. Then it performs the long task with the given state and removes it from
  /// the queue. If the task succeeds, it calls `taskCompleted()`. If the task fails, it calls `customAssertionFailure()`,
  /// logs the error, calls `taskFailed()` and rethrows the error.
  ///
  /// - throws: A `BackgroundProcessingClientError.noTasksInQueue` error if there are no tasks in the queue or an error
  /// from performing the long task.
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

  /// Executes the next task in the queue without scheduling a new task.
  ///
  /// - precondition: The task queue is not empty and no other task is being executed.
  /// - throws: A `BackgroundProcessingClientError.noTasksInQueue` error if the task queue is empty or a task is already
  /// being executed, or any error thrown by the `longTask.performTask` method.
  /// - note: This method is recursive and will call itself until the task queue is empty.
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

  /// Schedules a background processing task using the `BGTaskScheduler` API.
  ///
  /// - precondition: The `backgroundTaskScheduled` property must be `false`.
  /// - postcondition: The `backgroundTaskScheduled` property will be set to `true` if the task is successfully submitted,
  /// or `false` otherwise.
  ///
  /// - throws: An error if the task request cannot be submitted.
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

  /// Marks the current task as completed and executes the next one in the queue.
  ///
  /// - throws: An error if the execution of the next task fails.
  /// - note: This function should be called after a task is finished or cancelled.
  private func taskCompleted() async throws {
    resetBackgroundTask()
    if !taskQueue.isEmpty {
      try await executeNextTask()
    }
  }

  /// Stops the execution of the current task and resets the background task.
  ///
  /// This function should be called when a task fails to complete successfully.
  /// It sets the `isExecutingTask` property to `false` and calls the `resetBackgroundTask()` function
  /// to cancel the current background task and schedule a new one.
  private func taskFailed() {
    isExecutingTask = false
    resetBackgroundTask()
  }

  /// Ends the current background task and removes any scheduled background task.
  ///
  /// This function should be called when the app is about to enter the foreground or terminate.
  /// It ensures that the app does not consume unnecessary resources or violate the background execution policy.
  ///
  /// - note: This function does not check if there is an active or scheduled background task. It simply calls the methods
  /// to end and remove them.
  private func resetBackgroundTask() {
    endBackgroundTask()
    removeScheduledBackgroundTask()
  }

  /// Ends the background task associated with the app.
  ///
  /// - parameter backgroundTaskID: The identifier of the background task to end.
  /// - postcondition: The `backgroundTaskID` property is set to `.invalid`.
  private func endBackgroundTask() {
    UIApplication.shared.endBackgroundTask(backgroundTaskID)
    backgroundTaskID = .invalid
  }

  /// Cancels a scheduled background task with the given identifier.
  ///
  /// - parameter longTask: The `BGTask` object that represents the scheduled task.
  /// - postcondition: The `backgroundTaskScheduled` property is set to `false`.
  private func removeScheduledBackgroundTask() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: longTask.identifier)
    backgroundTaskScheduled = false
  }
}
