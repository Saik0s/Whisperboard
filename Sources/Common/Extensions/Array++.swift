import ComposableArchitecture

public extension Array {
  func deduplicatedArray<ID: Hashable>(_ keyPath: KeyPath<Element, ID>) -> Self {
    var set = Set<ID>()
    return filter { set.insert($0[keyPath: keyPath]).inserted }
  }
}

public extension Array where Element: Identifiable {
  var identifiedArray: IdentifiedArrayOf<Element> {
    IdentifiedArray(uniqueElements: deduplicatedArray(\.id), id: \.id)
  }

  @inlinable
  subscript(id id: Element.ID) -> Element? {
    get {
      first(where: { $0.id == id })
    }
    set {
      switch (firstIndex(where: { $0.id == id }), newValue) {
      case let (index?, newValue?):
        self[index] = newValue

      case (let index?, nil):
        remove(at: index)

      case (nil, let newValue?):
        append(newValue)

      case (nil, nil):
        break
      }
    }
  }
}
