@testable import AppKit
import AudioProcessing
import Common
import WhisperKit
import XCTest

class AudioProcessingTests: XCTestCase {
  var transcriptionStream: TranscriptionStream!
  var recordingTranscriptionStream: RecordingTranscriptionStream!

  override func setUp() {
    super.setUp()
    let audioProcessor = AudioProcessor()
    transcriptionStream = TranscriptionStream(audioProcessor: audioProcessor)
    recordingTranscriptionStream = RecordingTranscriptionStream.liveValue
  }

  override func tearDown() {
    transcriptionStream = nil
    recordingTranscriptionStream = nil
    super.tearDown()
  }

  func testAudioFileTranscription() async throws {
    // 1. Prepare the test audio file
    let bundle = Bundle(for: type(of: self))
    guard let audioURL = bundle.url(forResource: "example", withExtension: "wav") else {
      XCTFail("Test audio file not found")
      return
    }

    // 2. Load the model
    let modelName = "tiny.en"
    try await recordingTranscriptionStream.loadModel(modelName) { _ in }

    // 3. Transcribe the audio file
    let result = try await recordingTranscriptionStream.transcribeAudioFile(audioURL) { _, _ in true }

    // 4. Validate the transcription result
    XCTAssertFalse(result.text.isEmpty, "Transcription text should not be empty")
    XCTAssertFalse(result.segments.isEmpty, "Transcription segments should not be empty")

    // 5. Compare with expected transcription (you need to know the content of your test audio file)
    let expectedText = "This is a test audio file for transcription."
    XCTAssertTrue(result.text.lowercased().contains(expectedText.lowercased()), "Transcription should contain the expected text")

    // 6. Check transcription timings
    XCTAssertGreaterThan(result.timings.tokensPerSecond, 0, "Tokens per second should be greater than 0")
    XCTAssertGreaterThan(result.timings.fullPipeline, 0, "Full pipeline time should be greater than 0")
  }
}
