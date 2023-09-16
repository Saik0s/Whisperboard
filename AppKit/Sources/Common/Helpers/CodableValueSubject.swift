import Combine
import Foundation

// MARK: - CodableValueSubject

final class CodableValueSubject<Output: Codable>: Subject {
  typealias Failure = Error

  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  private var _value: Output?
  var value: Output? {
    get {
      if let _value { return _value }
      do {
        _value = try Output(fromFile: fileURL, decoder: decoder)
        return _value
      } catch {
        completion = .failure(error)
        return nil
      }
    }
    set {
      _value = newValue
      do {
        try newValue?.write(toFile: fileURL, encoder: encoder)
      } catch {
        completion = .failure(error)
      }
    }
  }

  private let lock = NSRecursiveLock()
  private var subscriptions = [CodableValueSubjectSubscription<Output>]()
  private var completion: Subscribers.Completion<Failure>?

  init(fileURL: URL, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
    self.fileURL = fileURL
    self.encoder = encoder
    self.decoder = decoder
  }

  func receive<Downstream: Subscriber>(subscriber: Downstream) where Downstream.Failure == Failure, Downstream.Input == Output {
    lock.lock(); defer { lock.unlock() }
    let subscription = CodableValueSubjectSubscription<Output>(downstream: AnySubscriber(subscriber))
    subscriber.receive(subscription: subscription)
    subscriptions.append(subscription)

    if let value {
      subscription.receive(value)
    }
    if let completion {
      subscription.receive(completion: completion)
    }
  }

  func send(subscription: Subscription) {
    lock.lock(); defer { lock.unlock() }
    subscription.request(.unlimited)
  }

  func send(_ value: Output) {
    lock.lock(); defer { lock.unlock() }
    self.value = value
    subscriptions.forEach { $0.receive(value) }
  }

  func send(completion: Subscribers.Completion<Failure>) {
    lock.lock(); defer { lock.unlock() }
    self.completion = completion
    subscriptions.forEach { subscription in subscription.receive(completion: completion) }
  }
}

// MARK: - CodableValueSubjectSubscription

final class CodableValueSubjectSubscription<Output>: Subscription {
  typealias Failure = Error

  private let downstream: AnySubscriber<Output, Failure>
  private var isCompleted = false
  private var demand: Subscribers.Demand = .none

  init(downstream: AnySubscriber<Output, Failure>) {
    self.downstream = downstream
  }

  func request(_ newDemand: Subscribers.Demand) {
    demand += newDemand
  }

  func cancel() {
    isCompleted = true
  }

  func receive(_ value: Output) {
    guard !isCompleted, demand > 0 else { return }

    demand += downstream.receive(value)
    demand -= 1
  }

  func receive(completion: Subscribers.Completion<Failure>) {
    guard !isCompleted else { return }
    isCompleted = true
    downstream.receive(completion: completion)
  }
}
