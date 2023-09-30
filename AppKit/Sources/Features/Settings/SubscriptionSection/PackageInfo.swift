//
// Created by Igor Tarasenko on 26/09/2023.
//

import Foundation

struct PackageInfo: Identifiable, Hashable {
  var id: String { identifier }
  var identifier: String
  var localizedPriceString: String
  var localizedIntroductoryPriceString: String
}
