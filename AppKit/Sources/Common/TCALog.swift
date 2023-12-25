import ComposableArchitecture
import DependenciesAdditions
import Foundation
import os

extension _ReducerPrinter {
  static func swiftLog(withStateChanges: Bool = false) -> Self {
    Self { receivedAction, oldState, newState in
      var message = "received action:\n"
      CustomDump.customDump(receivedAction, to: &message, indent: 2, maxDepth: 2)
      message.write("\n")
      if withStateChanges {
        message.write(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
      }
      @Dependency(\.logger) var logger: os.Logger
      logger.debug("\(message)")
    }
  }
}
