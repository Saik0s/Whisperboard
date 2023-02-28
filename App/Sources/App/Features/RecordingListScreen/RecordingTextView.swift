import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingCardView

struct RecordingTextView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordingCard>
  @ObservedObject var viewStore: ViewStoreOf<RecordingCard>

  init(store: StoreOf<RecordingCard>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    VStack(spacing: .grid(4)) {
      ExpandableText(viewStore.recordingInfo.text, lineLimit: 3, isExpanded: viewStore.binding(\.$isExpanded))
    }
    .multilineTextAlignment(.leading)
    .padding(.grid(4))
    .background(Color.DS.Background.secondary)
    .cornerRadius(.grid(4))
    .shadow(color: .DS.Background.accentAlt.darken().opacity(0.25),
            radius: viewStore.mode.isPlaying ? 12 : 0,
            y: viewStore.mode.isPlaying ? 8 : 0)
    .enableInjection()
  }
}
