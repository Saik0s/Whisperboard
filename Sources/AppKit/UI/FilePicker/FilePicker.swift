import SwiftUI
import UniformTypeIdentifiers

struct FilePicker<LabelView: View>: View {
  typealias PickedURLsCompletionHandler = (_ urls: [URL]) -> Void
  typealias LabelViewContent = () -> LabelView

  @State private var isPresented = false

  let types: [UTType]
  let allowMultiple: Bool
  let pickedCompletionHandler: PickedURLsCompletionHandler
  let labelViewContent: LabelViewContent

  init(
    types: [UTType],
    allowMultiple: Bool,
    onPicked completionHandler: @escaping PickedURLsCompletionHandler,
    @ViewBuilder label labelViewContent: @escaping LabelViewContent
  ) {
    self.types = types
    self.allowMultiple = allowMultiple
    pickedCompletionHandler = completionHandler
    self.labelViewContent = labelViewContent
  }

  init(types: [UTType], allowMultiple: Bool, title: String, onPicked completionHandler: @escaping PickedURLsCompletionHandler)
    where LabelView == Text {
    self.init(types: types, allowMultiple: allowMultiple, onPicked: completionHandler) { Text(title) }
  }

  var body: some View {
    Button(
      action: {
        if !isPresented { isPresented = true }
      },
      label: {
        labelViewContent()
      }
    )
    .disabled(isPresented)
    .sheet(isPresented: $isPresented) {
      FilePickerUIRepresentable(types: types, allowMultiple: allowMultiple, onPicked: pickedCompletionHandler)
    }
  }
}
