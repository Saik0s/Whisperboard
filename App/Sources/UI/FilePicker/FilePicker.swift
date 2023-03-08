import SwiftUI
import UniformTypeIdentifiers

public struct FilePicker<LabelView: View>: View {
  public typealias PickedURLsCompletionHandler = (_ urls: [URL]) -> Void
  public typealias LabelViewContent = () -> LabelView

  @State private var isPresented: Bool = false

  public let types: [UTType]
  public let allowMultiple: Bool
  public let pickedCompletionHandler: PickedURLsCompletionHandler
  public let labelViewContent: LabelViewContent

  public init(
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

  public init(types: [UTType], allowMultiple: Bool, title: String, onPicked completionHandler: @escaping PickedURLsCompletionHandler)
    where LabelView == Text {
    self.init(types: types, allowMultiple: allowMultiple, onPicked: completionHandler) { Text(title) }
  }

  public var body: some View {
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
