//
// WithInlineState.swift
//

import SwiftUI

public func withInlineState<Value>(initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> some View) -> some View {
  WithInlineState(initialValue: initialValue, content: content)
}

// MARK: - WithInlineState

private struct WithInlineState<Value, Content: View>: View {
  @State var value: Value

  let content: (Binding<Value>) -> Content

  init(initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
    _value = .init(initialValue: initialValue)
    self.content = content
  }

  var body: some View {
    content($value)
  }
}
