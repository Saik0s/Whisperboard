import Combine
import ComposableArchitecture

// MARK: - AsyncError

enum AsyncError: Error {
  case finishedWithoutValue
}

extension Publisher {
  func asAsync() async throws -> Output {
    try await withCheckedThrowingContinuation { continuation in
      var cancellable: UncheckedSendable<AnyCancellable>?
      var finishedWithoutValue = true

      cancellable = UncheckedSendable(first()
        .sink { result in
          switch result {
          case .finished:
            if finishedWithoutValue {
              continuation.resume(throwing: AsyncError.finishedWithoutValue)
            }

          case let .failure(error):
            continuation.resume(throwing: error)
          }
          cancellable?.value.cancel()
        } receiveValue: { value in
          finishedWithoutValue = false
          continuation.resume(with: .success(value))
        })
    }
  }

  func asAsyncThrowingStream() -> AsyncThrowingStream<Output, Failure> where Failure == Error {
    AsyncThrowingStream(Output.self) { continuation in
      let cancellable = UncheckedSendable(sink { completion in
        switch completion {
        case .finished:
          continuation.finish()

        case let .failure(error):
          continuation.finish(throwing: error)
        }
      } receiveValue: { output in
        continuation.yield(output)
      })

      continuation.onTermination = { _ in cancellable.value.cancel() }
    }
  }

  func asAsyncStream() -> AsyncStream<Output> where Failure == Never {
    AsyncStream(Output.self) { continuation in
      let cancellable = UncheckedSendable(sink { completion in
        switch completion {
        case .finished:
          continuation.finish()

        case .failure:
          assertionFailure("Should never fail")
        }
      } receiveValue: { output in
        continuation.yield(output)
      })

      continuation.onTermination = { _ in cancellable.value.cancel() }
    }
  }
}

extension Publisher {
  func replaceErrorMap(_ mapError: @escaping (Failure) -> Output) -> AnyPublisher<Output, Never> {
    `catch` { error in
      Just(mapError(error))
    }
    .eraseToAnyPublisher()
  }
}
