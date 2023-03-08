import SwiftUI
import UniformTypeIdentifiers

public struct FilePickerUIRepresentable: UIViewControllerRepresentable {
  public typealias UIViewControllerType = UIDocumentPickerViewController
  public typealias PickedURLsCompletionHandler = (_ urls: [URL]) -> Void

  @Environment(\.presentationMode) var presentationMode

  public let types: [UTType]
  public let allowMultiple: Bool
  public let pickedCompletionHandler: PickedURLsCompletionHandler

  public init(types: [UTType], allowMultiple: Bool, onPicked completionHandler: @escaping PickedURLsCompletionHandler) {
    self.types = types
    self.allowMultiple = allowMultiple
    pickedCompletionHandler = completionHandler
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.delegate = context.coordinator
    picker.allowsMultipleSelection = allowMultiple
    return picker
  }

  public func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

  public class Coordinator: NSObject, UIDocumentPickerDelegate {
    var parent: FilePickerUIRepresentable

    init(parent: FilePickerUIRepresentable) {
      self.parent = parent
    }

    public func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
      parent.pickedCompletionHandler(urls)
      parent.presentationMode.wrappedValue.dismiss()
    }
  }
}
