import UIKit

struct URLOpener {
  let responder: UIResponder

  func open(urlString: String) {
    if let url = URL(string: urlString) {
      var optionalResponder: UIResponder? = responder
      let selector = NSSelectorFromString("openURL:")
      while let responder = optionalResponder {
        if responder.responds(to: selector) {
          responder.perform(selector, with: url)
          return
        }
        optionalResponder = responder.next
      }
      print("Can't open", urlString)
    } else {
      print("Can't open", urlString)
    }
  }
}
