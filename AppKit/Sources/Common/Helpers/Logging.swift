import DependenciesAdditions
import Foundation
import os

let log = LoggerWrapper.self

// MARK: - LoggerWrapper

enum LoggerWrapper {
  enum Destination {
    case print
    case custom(format: String, handler: (Message, String) -> Void)
  }

  enum Settings {
    static var destinations: [Destination] = [.print]

    /// C - colored area start
    /// c - colored area end
    /// d - date
    /// t - time
    /// L - level
    /// F - file
    /// l - line
    /// f - function
    /// m - message
    static var osLogFormat: String = "%C%F:%l %m%c"
    static var timeFormatter: DateFormatter = .withDateFormat("HH:mm:ss.SSS")
    static var dateFormatter: DateFormatter = .withDateFormat("yyyy-MM-dd")
    static var emojisInsteadOfColors = true
  }

  struct Message {
    let value: Any
    let level: Level
    let function: StaticString
    let file: StaticString
    let line: UInt
    let column: UInt
    let date: Date
    var fileName: String {
      URL(fileURLWithPath: "\(file)").lastPathComponent
    }
  }

  enum Level: String {
    case verbose = "V"
    case debug = "D"
    case info = "I"
    case warning = "W"
    case error = "E"

    var color: Color {
      switch self {
      case .verbose:
        .blue

      case .debug:
        .green

      case .info:
        .cyan

      case .warning:
        .yellow

      case .error:
        .red
      }
    }
  }

  enum Color: String {
    case red = "\u{001B}[0;31m"
    case green = "\u{001B}[0;32m"
    case yellow = "\u{001B}[0;33m"
    case blue = "\u{001B}[0;34m"
    case magenta = "\u{001B}[0;35m"
    case cyan = "\u{001B}[0;36m"
    case white = "\u{001B}[0;37m"
    case reset = "\u{001B}[0;0m"

    var emoji: String {
      switch self {
      case .red:
        "❤️"
      case .green:
        "💚"
      case .yellow:
        "💛️"
      case .blue:
        "💙️"
      case .magenta:
        "💜"
      case .cyan:
        "🐳️"
      case .white:
        "🤍"
      case .reset:
        ""
      }
    }

    var value: String {
      Settings.emojisInsteadOfColors ? emoji : rawValue
    }
  }

  /// Creates message string from Message struct using format defined in Settings.format
  static func format(_ message: Message, format: String) -> String {
    format
      // C - colored area start
      .replacingOccurrences(of: "%C", with: message.level.color.value)
      // c - colored area end
      .replacingOccurrences(of: "%c", with: Color.reset.value)
      // d - date
      .replacingOccurrences(of: "%d", with: Settings.dateFormatter.string(from: message.date))
      // t - time
      .replacingOccurrences(of: "%t", with: Settings.timeFormatter.string(from: message.date))
      // L - level
      .replacingOccurrences(of: "%L", with: message.level.rawValue)
      // F - file
      .replacingOccurrences(of: "%F", with: message.fileName)
      // l - line
      .replacingOccurrences(of: "%l", with: "\(message.line)")
      // f - function
      .replacingOccurrences(of: "%f", with: "\(message.function)")
      // m - message
      .replacingOccurrences(of: "%m", with: "\(message.value)")
  }

  static func print(
    level: Level,
    _ message: @autoclosure () -> Any,
    _ function: StaticString = #function,
    _ file: StaticString = #file,
    _ line: UInt = #line,
    _ column: UInt = #column,
    _ date: Date = Date()
  ) {
    let message = Message(
      value: message(),
      level: level,
      function: function,
      file: file,
      line: line,
      column: column,
      date: date
    )
    for destination in Settings.destinations {
      switch destination {
      case .print:
        let formatted = Self.format(message, format: Settings.osLogFormat)
        switch message.level {
        case .error:
          osLogger.error("\(formatted)")

        case .warning:
          osLogger.warning("\(formatted)")

        case .info:
          osLogger.info("\(formatted)")

        case .debug:
          osLogger.debug("\(formatted)")

        case .verbose:
          osLogger.log("\(formatted)")
        }

      case let .custom(format, handler):
        let formatted = Self.format(message, format: format)
        handler(message, formatted)
      }
    }
  }

  private static var osLogger: os.Logger {
    @Dependency(\.logger) var logger: os.Logger
    return logger
  }
}

extension LoggerWrapper {
  static func verbose(
    _ items: Any...,
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    column: UInt = #column
  ) {
    LoggerWrapper.print(level: .verbose, message(from: items), function, file, line, column)
  }

  static func debug(
    _ items: Any...,
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    column: UInt = #column
  ) {
    LoggerWrapper.print(level: .debug, message(from: items), function, file, line, column)
  }

  static func info(
    _ items: Any...,
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    column: UInt = #column
  ) {
    LoggerWrapper.print(level: .info, message(from: items), function, file, line, column)
  }

  static func warning(
    _ items: Any...,
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    column: UInt = #column
  ) {
    LoggerWrapper.print(level: .warning, message(from: items), function, file, line, column)
  }

  static func error(
    _ items: Any...,
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    column: UInt = #column
  ) {
    LoggerWrapper.print(level: .error, message(from: items), function, file, line, column)
  }

  private static func message(from items: [Any]) -> Any {
    guard items.count > 1 else {
      return items.first ?? items
    }

    return items.map { "\($0)" }.joined(separator: " ")
  }
}
