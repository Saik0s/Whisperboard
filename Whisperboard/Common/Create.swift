//
// Created by Igor Tarasenko on 24/12/2022.
//

import Foundation

func create<T: AnyObject>(_ object: T, configure: (T) -> Void) -> T {
  configure(object)
  return object
}

func create<T: NSObject>(configure: (T) -> Void) -> T {
  let object = T.init()
  configure(object)
  return object
}
