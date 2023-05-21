import AppDevUtils
import Dependencies
import Foundation
import Functions
import RecognitionKit
import Supabase
import DeviceCheck

// MARK: - LongTaskTranscriptError

enum LongTaskTranscriptError: Error {
  case noRecordingInfo
  case failedToTranscribe
}

extension LongTask {
  /// Creates and returns a long task that transcribes an audio recording and updates the storage.
  ///
  /// - parameter id: The identifier of the recording to be transcribed.
  /// - throws: A `LongTaskTranscriptError` if the recording info is not found or the transcription fails.
  /// - note: The task uses the dependencies injected by the `@Dependency` property wrapper.
  static var transcription: LongTask<RecordingInfo.ID> {
    LongTask<RecordingInfo.ID>(identifier: "me.igortarasenko.Whisperboard") { id in
      @Dependency(\.storage) var storage: StorageClient
      @Dependency(\.settings) var settings: SettingsClient

      guard let recordingInfo = storage.read()[id: id] else {
        throw LongTaskTranscriptError.noRecordingInfo
      }

      let fileURL = storage.audioFileURLWithName(recordingInfo.fileName)
      let language = settings.settings().voiceLanguage
      let text: String
      if settings.settings().isRemoteTranscriptionEnabled {
        text = try await remoteTranscription(fileURL: fileURL, language: language)
      } else {
        text = try await localTranscription(settings: settings, fileURL: fileURL, language: language)
      }
      try storage.update(recordingInfo.id) {
        $0.text = text
        $0.isTranscribed = true
      }
    }
  }

  private static func localTranscription(
    settings: SettingsClient,
    fileURL: URL,
    language: VoiceLanguage
  ) async throws -> String {
    @Dependency(\.transcriber) var transcriber: TranscriberClient
    let isParallel = settings.settings().isParallelEnabled
    let text = try await transcriber.transcribeAudio(fileURL, language, isParallel)
    return text
  }

  private static func remoteTranscription(
    fileURL: URL,
    language _: VoiceLanguage
  ) async throws -> String {
    let text = try await uploadFileToTranscription(fileURL: fileURL)
    log.debug(text)
    return text
  }
}

// MARK: - RemoteTranscriptionError

enum RemoteTranscriptionError: Error {
  case decodingError(String)
}

struct TranscriptionResponse: Decodable {
}

private func uploadFileToTranscription(fileURL: URL) async throws -> String {
  let supabaseUrl = Secrets.supabaseUrl
  let supabaseKey = Secrets.supabaseKey
  let supabaseClient = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseKey, options: .init())
  let functionName = "transcription"

  let fileData = try Data(contentsOf: fileURL)
  let base64Audio = fileData.base64EncodedString()
  let jsonBody: [String: String] = ["file_string": base64Audio]
  let device_identifier = await getDeviceIdentifier()

  let headers = [
    "Authorization": "Bearer \(supabaseKey)",
    "x-device-identifier": device_identifier
  ]
  supabaseClient.functions.setAuth(token: supabaseKey)
  let options = FunctionInvokeOptions(headers: headers, body: jsonBody)
  let response: [String: String] = try await supabaseClient.functions.invoke(functionName: functionName, invokeOptions: options)
  log.debug(response)
  return "\(response)"
}

private func getDeviceIdentifier() async -> String {
  do {
    return try await DCDevice.current.generateToken().utf8String
  } catch {
    log.error(error)
    if let device_identifier = UserDefaults.standard.string(forKey: "device_identifier") {
      return device_identifier
    } else {
      let device_identifier = UUID().uuidString
      UserDefaults.standard.set(device_identifier, forKey: "device_identifier")
      return device_identifier
    }
  }
}
