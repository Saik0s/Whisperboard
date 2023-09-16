import ComposableArchitecture
import Foundation
import DependenciesAdditions
import os

extension _ReducerPrinter {
  static func swiftLog() -> Self {
    Self { receivedAction, oldState, newState in
      var message = "received action:\n"
      CustomDump.customDump(receivedAction, to: &message, indent: 2)
      message.write("\n")
      message.write(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
      @Dependency(\.logger) var logger: os.Logger
      logger.debug("\(message)")
    }
  }
}
