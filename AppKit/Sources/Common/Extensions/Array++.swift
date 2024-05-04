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

  @inlinable
  public subscript(id id: Element.ID) -> Element? {
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
