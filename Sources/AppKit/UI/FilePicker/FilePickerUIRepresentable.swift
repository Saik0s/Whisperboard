import SwiftUI
import UniformTypeIdentifiers

struct FilePickerUIRepresentable: UIViewControllerRepresentable {
  typealias UIViewControllerType = UIDocumentPickerViewController
  typealias PickedURLsCompletionHandler = (_ urls: [URL]) -> Void

  @Environment(\.presentationMode) var presentationMode

  let types: [UTType]
  let allowMultiple: Bool
  let pickedCompletionHandler: PickedURLsCompletionHandler

  init(types: [UTType], allowMultiple: Bool, onPicked completionHandler: @escaping PickedURLsCompletionHandler) {
    self.types = types
    self.allowMultiple = allowMultiple
    pickedCompletionHandler = completionHandler
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.delegate = context.coordinator
    picker.allowsMultipleSelection = allowMultiple
    return picker
  }

  func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

  class Coordinator: NSObject, UIDocumentPickerDelegate {
    var parent: FilePickerUIRepresentable

    init(parent: FilePickerUIRepresentable) {
      self.parent = parent
    }

    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
      parent.pickedCompletionHandler(urls)
      parent.presentationMode.wrappedValue.dismiss()
    }
  }
}
