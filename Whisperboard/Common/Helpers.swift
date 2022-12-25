import Foundation
import ComposableArchitecture

let dateComponentsFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.minute, .second]
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()

let fileNameDateFormatter: DateFormatter = create {
  $0.dateFormat = "yyyy_MM_dd_HH_mm_ss"
}

extension Array {
  func deduplicatedArray<Value: Hashable>(_ keyPath: KeyPath<Element, Value>) -> Self {
    let set = Set(map { $0[keyPath: keyPath] })
    return filter { set.contains($0[keyPath: keyPath]) }
  }
}

extension Array where Element: Identifiable {
  var identifiedArray: IdentifiedArrayOf<Element> {
    IdentifiedArray(uniqueElements: deduplicatedArray(\.id), id: \.id)
  }
}
