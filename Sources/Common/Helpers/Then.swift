import Foundation
import SwiftUI

// MARK: - Then

public protocol Then {}

public extension Then where Self: Any {
  @inlinable
  func with(_ block: (inout Self) throws -> Void) rethrows -> Self {
    var copy = self
    try block(&copy)
    return copy
  }

  @inlinable
  func with<Value>(_ keyPath: WritableKeyPath<Self, Value>, setTo value: Value) -> Self {
    with { $0[keyPath: keyPath] = value }
  }

  @inlinable
  func `do`(_ block: (Self) throws -> Void) rethrows {
    try block(self)
  }
}

public extension Then where Self: AnyObject {
  @inlinable
  func then(_ block: (Self) throws -> Void) rethrows -> Self {
    try block(self)
    return self
  }
}

// MARK: - NSObject + Then

extension NSObject: Then {}

// MARK: - CGPoint + Then

extension CGPoint: Then {}

// MARK: - CGRect + Then

extension CGRect: Then {}

// MARK: - CGSize + Then

extension CGSize: Then {}

// MARK: - CGVector + Then

extension CGVector: Then {}

// MARK: - Array + Then

extension Array: Then {}

// MARK: - Dictionary + Then

extension Dictionary: Then {}

// MARK: - Set + Then

extension Set: Then {}

// MARK: - JSONDecoder + Then

extension JSONDecoder: Then {}

// MARK: - JSONEncoder + Then

extension JSONEncoder: Then {}

// MARK: - EdgeInsets + Then

extension EdgeInsets: Then {}
