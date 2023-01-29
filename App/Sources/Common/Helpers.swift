import ComposableArchitecture
import Foundation
import AppDevUtils

let dateComponentsFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.minute, .second]
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()

let fileNameDateFormatter: DateFormatter = create {
  $0.dateFormat = "yyyy_MM_dd_HH_mm_ss"
}
