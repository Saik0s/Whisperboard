import AVFoundation
@testable import RecognitionKit
import XCTest

// MARK: - StreamTests

class StreamTests: XCTestCase {
  func testStreamContextInitialization() {
    let params = StreamParams(model: "model", language: "en")
    let streamContext = StreamContext(params: params)
    XCTAssertNotNil(streamContext)
    XCTAssertEqual(streamContext?.params.model, "model")
    XCTAssertEqual(streamContext?.params.language, "en")
    XCTAssertNotNil(streamContext?.audioEngine)
    XCTAssertNotNil(streamContext?.whisperContext)
    XCTAssertEqual(streamContext?.pcmBuffer.count, 0)
  }

  func testStreamContextDeinitialization() {
    var streamContext: StreamContext? = StreamContext(params: StreamParams(model: "model", language: "en"))
    XCTAssertNotNil(streamContext)
    streamContext = nil
    XCTAssertNil(streamContext?.audioEngine)
    XCTAssertNil(streamContext?.whisperContext)
  }

  func testSpeechRecognition() {
    // Load the model and audio file from the resources folder
    let modelURL = Files.App.Resources.ggmlTinyBin.url
    let audioURL = Files.RecognitionKit.TestResources.jfkWav.url

    // Initialize the SpeechRecognizer with the loaded model
    let speechRecognizer = SpeechRecognizer(model: modelURL.path, language: "en")

    // Set up an expectation to wait for the recognition result
    let recognitionExpectation = expectation(description: "Recognition completed")

    // Start the speech recognition and process the audio file
    if let audioData = try? Data(contentsOf: audioURL),
       let audioBuffer = audioData.toPCMBuffer() {
      speechRecognizer.start(callback: { text, _, _ in
        // Check the recognized text
        XCTAssertEqual(text, "expected text")

        // Fulfill the expectation
        recognitionExpectation.fulfill()
      }, testBuffer: audioBuffer)
    } else {
      XCTFail("Failed to load audio data")
    }

    // Load the audio file and send it to the SpeechRecognizer
    if let audioData = try? Data(contentsOf: audioURL),
       let audioBuffer = audioData.toPCMBuffer() {
      speechRecognizer.streamContext?
        .pcmBuffer = Array(UnsafeBufferPointer(start: audioBuffer.floatChannelData?[0], count: Int(audioBuffer.frameLength)))
      speechRecognizer.runRecognition()
    } else {
      XCTFail("Failed to load audio data")
    }

    // Wait for the recognition result
    waitForExpectations(timeout: 10, handler: nil)

    // Stop the speech recognition
    speechRecognizer.stop()
  }
}

// Helper extension to convert Data to AVAudioPCMBuffer
extension Data {
  func toPCMBuffer() -> AVAudioPCMBuffer? {
    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)
    let pcmBuffer = AVAudioPCMBuffer(
      pcmFormat: audioFormat!,
      frameCapacity: UInt32(count) / audioFormat!.streamDescription.pointee.mBytesPerFrame
    )
    pcmBuffer?.frameLength = pcmBuffer!.frameCapacity
    let channels = UnsafeBufferPointer(start: pcmBuffer?.floatChannelData, count: Int(audioFormat!.channelCount))
    withUnsafeBytes { bytes in
      channels[0].update(from: bytes.bindMemory(to: Float.self).baseAddress!, count: Int(pcmBuffer!.frameLength))
    }
    return pcmBuffer
  }
}
