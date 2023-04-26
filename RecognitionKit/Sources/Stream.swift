import AVFoundation
import Foundation
import whisper

// MARK: - StreamContext

public class StreamContext {
  public let params: StreamParams
  public var audioEngine: AVAudioEngine
  public var whisperContext: OpaquePointer?
  public var pcmBuffer: [Float] = []
  public var recognitionStartTime: Date

  public init?(params: StreamParams) {
    self.params = params
    audioEngine = AVAudioEngine()
    recognitionStartTime = Date()
    guard let whisperContext = whisper_init_from_file(params.model) else {
      return nil
    }
    self.whisperContext = whisperContext
  }

  deinit {
    whisper_free(whisperContext)
  }
}

// MARK: - StreamParams

public struct StreamParams {
  public let model: String
  public let language: String
}

public func streamInit(params: StreamParams) -> StreamContext? {
  StreamContext(params: params)
}

// MARK: - SpeechRecognizer

public class SpeechRecognizer {
  var streamContext: StreamContext?
  var recognitionCallback: ((String, TimeInterval, TimeInterval) -> Void)?

  public init(model: String, language: String) {
    let params = StreamParams(model: model, language: language)
    streamContext = streamInit(params: params)
  }

  public func start(callback: @escaping (String, TimeInterval, TimeInterval) -> Void, testBuffer: AVAudioPCMBuffer? = nil) {
    guard let streamContext else { return }

    if let testBuffer {
      streamContext.pcmBuffer = Array(UnsafeBufferPointer(start: testBuffer.floatChannelData?[0], count: Int(testBuffer.frameLength)))
      runRecognition()
    } else {
      recognitionCallback = callback
      let audioEngine = streamContext.audioEngine
      let inputNode = audioEngine.inputNode

      let format = inputNode.outputFormat(forBus: 0)

      inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
        guard let strongSelf = self else { return }
        let channelData = buffer.floatChannelData?[0]
        let frameLength = Int(buffer.frameLength)

        for i in 0 ..< frameLength {
          strongSelf.streamContext?.pcmBuffer.append(channelData![i])
        }

        strongSelf.runRecognition()
      }

      do {
        try audioEngine.start()
      } catch {
        print("Error starting audio engine: \(error)")
      }
    }
  }

  public func stop() {
    streamContext?.audioEngine.stop()
    streamContext?.audioEngine.inputNode.removeTap(onBus: 0)
  }

  func runRecognition() {
    guard let streamContext, let whisperContext = streamContext.whisperContext else { return }

    var wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
    wparams.no_context = true
    wparams.language = streamContext.params.language.cString(using: .utf8)?.withUnsafeBufferPointer {
      UnsafePointer($0.baseAddress)
    }

    let pcmBuffer = streamContext.pcmBuffer
    let recognitionResult = whisper_full(whisperContext, wparams, pcmBuffer, Int32(pcmBuffer.count))

    if recognitionResult != 0 {
      print("Failed to process audio")
      return
    }

    let nSegments = whisper_full_n_segments(whisperContext)
    for i in 0 ..< nSegments {
      let text = String(cString: whisper_full_get_segment_text(whisperContext, i))
      let segmentT0 = TimeInterval(whisper_full_get_segment_t0(whisperContext, i)) / 1000
      let segmentT1 = TimeInterval(whisper_full_get_segment_t1(whisperContext, i)) / 1000
      recognitionCallback?(text, segmentT0, segmentT1)
    }
  }
}
