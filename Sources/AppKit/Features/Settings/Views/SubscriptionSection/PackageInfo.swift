import Common
import Foundation

struct PackageInfo: Identifiable, Hashable {
  var id: String { identifier }
  var identifier: String
  var localizedPriceString: String
  var localizedIntroductoryPriceString: String
}
