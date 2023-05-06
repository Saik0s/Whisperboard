import AppDevUtils
import SwiftUI

struct PlayButton: View {
  var isPlaying: Bool
  var action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      Image(systemName: isPlaying ? "pause.circle" : "play.circle")
        .resizable()
        .aspectRatio(1, contentMode: .fit)
        .foregroundColor(isPlaying ? .DS.Text.accent : .DS.Text.accentAlt)
        .symbolRenderingMode(.hierarchical)
        .animation(.easeInOut(duration: 0.15), value: isPlaying)
    }
    .aspectRatio(1, contentMode: .fit)
    .frame(width: 35, height: 35)
  }
}
