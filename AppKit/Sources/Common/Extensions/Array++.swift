import ComposableArchitecture

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
