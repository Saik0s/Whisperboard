import SwiftUI

func withInlineState<Value>(initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> some View) -> some View {
  WithInlineState(initialValue: initialValue, content: content)
}

// MARK: - WithInlineState

/// A view that stores a value, and updates a child view whenever that value
/// changes.
///
/// The `WithInlineState` view is used to store a value and update a child view
/// whenever that value changes. When the value changes, the child view is
/// updated.
///
/// The following example shows a `WithInlineState` view that stores a boolean
/// value in the `isEnabled` property, and updates a `Button` whenever that
/// value changes:
///
///     struct ContentView: View {
///         var body: some View {
///             WithInlineState(initialValue: true) { isEnabled in
///                 Button("Tap Me") {
///                     isEnabled.wrappedValue.toggle()
///                 }
///                 .disabled(!isEnabled.wrappedValue)
///             }
///         }
///     }
///
/// - Parameters:
///   - initialValue: The initial value to store.
///   - content: A view builder that creates the child view using the stored
///     value.
struct WithInlineState<Value, Content: View>: View {
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
