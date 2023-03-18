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
    ZStack {
      if viewStore.recordingInfo.isTranscribed {
        ExpandableText(viewStore.recordingInfo.text, lineLimit: 3, isExpanded: viewStore.binding(\.$isExpanded))
      } else {
        Button {
          viewStore.send(.transcribeTapped)
        } label: {
          Text("Transcribe")
            .font(.DS.bodyM)
            .foregroundColor(.DS.Text.base)
            .padding(.grid(2))
            .background(Color.DS.Background.accent)
            .continuousCornerRadius(.grid(2))
            .padding(.grid(4))
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
    .multilineTextAlignment(.leading)
    .padding(.grid(4))
    .foregroundColor(.DS.Text.base)
    .background {
      Color.DS.Background.secondary
        .cornerRadius(.grid(4))
        .shadow(color: .DS.Background.accentAlt.darken().opacity(0.25),
                radius: viewStore.mode.isPlaying ? 12 : 0,
                y: viewStore.mode.isPlaying ? 8 : 0)
    }
    .clipped()
    .enableInjection()
  }
}
