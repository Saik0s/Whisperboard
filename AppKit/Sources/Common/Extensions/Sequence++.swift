import Foundation

extension Sequence {
  func filterNil<T>() -> [T] where Element == T? {
    compactMap { $0 }
  }
}
