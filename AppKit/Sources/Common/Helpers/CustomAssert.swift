import Foundation

func customAssert(_ condition: @autoclosure () -> Bool,
                  _ message: @autoclosure () -> String = "",
                  useDebugBreakpoint: Bool = true,
                  file: StaticString = #file,
                  line: UInt = #line) {
  guard condition() == false else {
    return
  }

  log.error("assertion failed in \(file):\(line) \(message())")

  if useDebugBreakpoint {
    #if DEBUG
      raise(SIGINT)
    #endif
  } else {
    assertionFailure(message(), file: file, line: line)
  }
}

func customAssertionFailure(_ message: @autoclosure () -> String = String(),
                            useDebugBreakpoint: Bool = true,
                            file: StaticString = #file,
                            line: UInt = #line) {
  customAssert(false, message(), useDebugBreakpoint: useDebugBreakpoint, file: file, line: line)
}
