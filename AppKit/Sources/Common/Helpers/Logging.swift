import Foundation
import Logging
import os
import PulseLogHandler

let bundleID = Bundle.main.bundleIdentifier ?? "App"
let osLogger = os.Logger(subsystem: bundleID, category: "General")

// MARK: - Bootstrap Logger

public let logs: Logging.Logger = {
  let fileLogger: FileLogging? = logFileURL.flatMap { try? FileLogging(to: $0) }
  LoggingSystem.bootstrap { label in
    UnifiedLogHandler(fileLogger: fileLogger, osLogger: osLogger, pulseLogger: PersistentLogHandler(label: label))
  }
  return Logging.Logger(label: bundleID)
}()

public let logFileURL: URL? = {
  let logsDir: URL = .cachesDirectory.appendingPathComponent("logs")

  let options: ISO8601DateFormatter.Options = [.withDashSeparatorInDate, .withFullDate]
  let dateString = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: options)
  let fileName = "\(dateString).log"
  let url: URL = logsDir.appendingPathComponent(fileName)

  for url in (try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: [])) ?? []
    where url.lastPathComponent != fileName {
    do {
      try FileManager.default.removeItem(at: url)
    } catch {
      osLogger.error("Encountered error while removing old logs: \(error.localizedDescription)")
    }
  }

  return url
}()

// MARK: - ExtraLogHandler

public enum ExtraLogHandler {
  public static var isLoggingAllowed = true

  public static var sessionLogs: [String] = []

  public static var closure: ((
    _ level: Logging.Logger.Level,
    _ message: Logging.Logger.Message,
    _ metadata: Logging.Logger.Metadata?,
    _ source: String,
    _ file: String,
    _ function: String,
    _ line: UInt
  ) -> Void)?
}

// MARK: - UnifiedLogHandler

class UnifiedLogHandler: LogHandler {
  var logLevel: Logging.Logger.Level = .trace
  var metadata = Logging.Logger.Metadata()
  private var prettyMetadata: String?
  private var fileLogger: FileLogging?
  private let osLogger: os.Logger
  private let pulseLogger: PersistentLogHandler

  init(fileLogger: FileLogging?, osLogger: os.Logger, pulseLogger: PersistentLogHandler) {
    self.fileLogger = fileLogger
    self.osLogger = osLogger
    self.pulseLogger = pulseLogger
  }

  subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
    get {
      metadata[metadataKey]
    }
    set {
      metadata[metadataKey] = newValue
      prettyMetadata = prettify(metadata)
    }
  }

  func log(
    level: Logging.Logger.Level,
    message: Logging.Logger.Message,
    metadata: Logging.Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
  ) {
    guard ExtraLogHandler.isLoggingAllowed else { return }

    let combinedMetadata = metadata.map { self.metadata.merging($0, uniquingKeysWith: { _, new in new }) } ?? self.metadata
    let formattedMessage = formatMessage(level: level, message: message, metadata: combinedMetadata, file: file, line: line)

    ExtraLogHandler.sessionLogs.append(formattedMessage)

    // Log to Pulse
    pulseLogger.log(level: level, message: "\(formattedMessage)", metadata: metadata, file: file, function: function, line: line)

    // Log to file if available
    fileLogger?.stream.write(formattedMessage)

    // Log to os.Logger
    osLogger.log(level: OSLogType.from(loggerLevel: level), "\(formattedMessage)")

    // Additional custom logging
    ExtraLogHandler.closure?(level, message, metadata, source, file, function, line)
  }

  private func formatMessage(
    level: Logging.Logger.Level,
    message: Logging.Logger.Message,
    metadata: Logging.Logger.Metadata,
    file: String,
    line: UInt
  ) -> String {
    let metaString = prettify(metadata) ?? ""
    return "\(timestamp()) \(level) [\(file):\(line)] \(metaString) \(message)"
  }

  private func prettify(_ metadata: Logging.Logger.Metadata) -> String? {
    if metadata.isEmpty {
      return nil
    }
    return metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
  }

  private func timestamp() -> String {
    let options: ISO8601DateFormatter.Options = [.withColonSeparatorInTime, .withFullTime, .withFractionalSeconds]
    return ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: options)
  }
}

// MARK: - FileHandlerOutputStream

/// Adapted from https://nshipster.com/textoutputstream/
struct FileHandlerOutputStream: TextOutputStream {
  enum FileHandlerOutputStream: Error {
    case couldNotCreateFile
  }

  private let fileHandle: FileHandle
  let encoding: String.Encoding

  init(localFile url: URL, encoding: String.Encoding = .utf8) throws {
    if !FileManager.default.fileExists(atPath: url.path) {
      guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
        throw NSError(
          domain: "FileHandlerOutputStream",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Could not create file at \(url.path)"]
        )
      }
    }

    let fileHandle = try FileHandle(forWritingTo: url)
    fileHandle.seekToEndOfFile()
    self.fileHandle = fileHandle
    self.encoding = encoding
  }

  mutating func write(_ string: String) {
    if let data = string.data(using: encoding) {
      fileHandle.write(data)
    }
  }
}

// MARK: - FileLogging

struct FileLogging {
  var stream: TextOutputStream
  private var localFile: URL

  init(to localFile: URL) throws {
    stream = try FileHandlerOutputStream(localFile: localFile)
    self.localFile = localFile
  }
}

extension OSLogType {
  static func from(loggerLevel: Logging.Logger.Level) -> Self {
    switch loggerLevel {
    case .trace:
      // `OSLog` doesn't have `trace`, so use `debug`
      .debug

    case .debug:
      .debug

    case .info:
      .info

    case .notice:
      // https://developer.apple.com/documentation/os/logging/generating_log_messages_from_your_code
      // According to the documentation, `default` is `notice`.
      .default

    case .warning:
      // `OSLog` doesn't have `warning`, so use `info`
      .info

    case .error:
      .error

    case .critical:
      .fault
    }
  }
}
