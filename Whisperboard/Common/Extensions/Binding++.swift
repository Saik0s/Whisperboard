//
// Binding++.swift
//

import SwiftUI

public extension Binding {
  func mirror(to other: Binding) -> Self {
    .init(
      get: { wrappedValue },
      set: {
        wrappedValue = $0
        other.wrappedValue = $0
      }
    )
  }
}

public extension Binding {
  func onSet(_ body: @escaping (Value) -> Void) -> Self {
    .init(
      get: { wrappedValue },
      set: { wrappedValue = $0; body($0) }
    )
  }

  func printOnSet() -> Self {
    onSet {
      print("Set value: \($0)")
    }
  }
}

public extension Binding {
  func onChange(perform action: @escaping (Value) -> Void) -> Self where Value: Equatable {
    .init(
      get: { wrappedValue },
      set: { newValue in
        let oldValue = wrappedValue

        wrappedValue = newValue

        if newValue != oldValue {
          action(newValue)
        }
      }
    )
  }

  func onChange(toggle value: Binding<Bool>) -> Self where Value: Equatable {
    onChange { _ in
      value.wrappedValue.toggle()
    }
  }
}

public extension Binding {
  func removeDuplicates() -> Self where Value: Equatable {
    .init(
      get: { wrappedValue },
      set: { newValue in
        let oldValue = wrappedValue

        guard newValue != oldValue else {
          return
        }

        wrappedValue = newValue
      }
    )
  }
}
