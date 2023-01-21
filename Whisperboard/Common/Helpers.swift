import ComposableArchitecture
import Foundation

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
  func deduplicatedArray(_ keyPath: KeyPath<Element, some Hashable>) -> Self {
    let set = Set(map { $0[keyPath: keyPath] })
    return filter { set.contains($0[keyPath: keyPath]) }
  }
}

extension Array where Element: Identifiable {
  var identifiedArray: IdentifiedArrayOf<Element> {
    IdentifiedArray(uniqueElements: deduplicatedArray(\.id), id: \.id)
  }
}
