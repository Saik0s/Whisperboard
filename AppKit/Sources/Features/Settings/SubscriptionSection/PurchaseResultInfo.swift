//
// Created by Igor Tarasenko on 26/09/2023.
//

import Foundation
import RevenueCat

struct PurchaseResultInfo: Identifiable, Hashable {
  var id: String { identifier }
  var identifier: String
  var localizedPriceString: String
  var localizedIntroductoryPriceString: String

  var transaction: StoreTransaction?
  var customerInfo: CustomerInfo
  var userCancelled: Bool
}
