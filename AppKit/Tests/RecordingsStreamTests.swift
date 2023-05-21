import AsyncAlgorithms
import Combine
import CustomDump
import Dependencies
@testable import WhisperBoardKit
import XCTest

class RecordingsStreamTests: XCTestCase {
  var transcriptionSubject: AsyncChannel<[FileName: TranscriptionState]>!
  var recordingsSubject: AsyncChannel<[RecordingInfo]>!

  override func setUp() {
    super.setUp()
  }

  override func invokeTest() {
    transcriptionSubject = AsyncChannel<[FileName: TranscriptionState]>()
    recordingsSubject = AsyncChannel<[RecordingInfo]>()
    withDependencies {
      $0.transcriber.transcriptionStateStream = transcriptionSubject.eraseToStream()
      $0.storage.recordingsInfoStream = recordingsSubject.eraseToStream()
    } operation: {
      super.invokeTest()
    }
  }

  func testRecordingsStreamOutputsCorrectValues() {
    // Given
    let date = Date()
    let expectedOutput = [
      RecordingEnvelop(
        RecordingInfo(fileName: "file1", date: date, isTranscribed: true),
        TranscriptionState(progress: .transcribing, segments: [], finalText: "Hello world")
      ),
    ]
    @Dependency(\.recordingsStream) var recordingsStream: AsyncStream<[RecordingEnvelop]>

    // When
    let expectation = XCTestExpectation(description: "Awaiting publisher")

    let actualOutput = ActorIsolated([RecordingEnvelop]())

    Task {
      for await value in recordingsStream {
        await actualOutput.setValue(value)
      }
    }

    // Simulate storage and transcription stream updating values for file1 several times
    for _ in 0 ..< 25 {
      Task.detached {
        await self.recordingsSubject.send([
          RecordingInfo(fileName: "file1", date: date),
        ])
        expectation.fulfill()
      }

      Task.detached {
        await self.transcriptionSubject.send([
          "file1": TranscriptionState(progress: .transcribing, segments: [], finalText: "Hello"),
        ])
        expectation.fulfill()
      }

      Task.detached {
        await self.recordingsSubject.send([
          RecordingInfo(fileName: "file1", date: date),
        ])
        expectation.fulfill()
      }

      Task.detached {
        await self.transcriptionSubject.send([
          "file1": TranscriptionState(progress: .transcribing, segments: [], finalText: "Hello world"),
        ])
        expectation.fulfill()
      }

      Task.detached {
        await self.recordingsSubject.send([
          RecordingInfo(fileName: "file1", date: date, isTranscribed: true),
        ])
        expectation.fulfill()
      }
    }

    expectation.expectedFulfillmentCount = 125

    // Wait for the expectation to be fulfilled or timeout
    wait(for: [expectation], timeout: 5)

    // Then
    Task {
      await actualOutput.withValue { value in
        XCTAssertEqual(value, expectedOutput)
      }
    }
  }
}
