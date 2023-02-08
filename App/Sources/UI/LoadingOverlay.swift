import AppDevUtils
import SwiftUI

// MARK: - LoadingOverlay

struct LoadingOverlay: View {
  var body: some View {
    ZStack {
      Color.DS.Shadow.primary.ignoresSafeArea()
      ProgressView()
    }
  }
}

// MARK: - LoadingOverlay_Previews

struct LoadingOverlay_Previews: PreviewProvider {
  static var previews: some View {
    LoadingOverlay()
  }
}
