
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingCardView

struct RecordingCardView: View {
  @ObserveInjection var inject

  let store: StoreOf<RecordingCard>

  @ObservedObject var viewStore: ViewStoreOf<RecordingCard>
  @State var showItem = false

  init(store: StoreOf<RecordingCard>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  var body: some View {
    Button { viewStore.send(.recordingSelected) } label: {
      cardView
    }
    .cardButtonStyle()
  }

  var cardView: some View {
    VStack(spacing: .grid(4)) {
      HStack(spacing: .grid(4)) {
        PlayButton(isPlaying: viewStore.mode.isPlaying) {
          viewStore.send(.playButtonTapped, animation: .easeIn(duration: 0.3))
        }

        VStack(alignment: .leading, spacing: .grid(1)) {
          if viewStore.recording.title.isEmpty {
            Text("Untitled")
              .font(.DS.headlineS)
              .foregroundColor(.DS.Text.subdued)
              .opacity(0.5)
          } else {
            Text(viewStore.recording.title)
              .font(.DS.headlineS)
              .foregroundColor(.DS.Text.base)
          }

          Text(viewStore.dateString)
            .font(.DS.captionM)
            .foregroundColor(.DS.Text.subdued)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(viewStore.currentTimeString)
          .font(.DS.date)
          .foregroundColor(
            viewStore.mode.isPlaying
              ? Color.DS.Text.accent
              : Color.DS.Text.base
          )
      }

      if viewStore.mode.isPlaying {
        WaveformProgressView(
          store: store.scope(
            state: { $0.waveform },
            action: { .waveform($0) }
          )
        )
        .transition(.scale.combined(with: .opacity))
      }

      ZStack(alignment: .top) {
        VStack(alignment: .leading, spacing: .grid(2)) {
          Text(viewStore.transcription)
            .font(.DS.bodyS)
            .foregroundColor(.DS.Text.base)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)

          if viewStore.recording.isTranscribed && !viewStore.isTranscribing {
            HStack(spacing: .grid(2)) {
              CopyButton(viewStore.transcription) {
                Image(systemName: "doc.on.clipboard")
              }

              ShareLink(item: viewStore.transcription) {
                Image(systemName: "paperplane")
              }
            }.iconButtonStyle()
          }
        }

        if viewStore.isTranscribing || viewStore.queuePosition != nil || !viewStore.recording.isTranscribed {
          ZStack {
            Rectangle()
              .fill(.ultraThinMaterial)
              .roundedCorners(radius: 8, corners: [.bottomLeft, .bottomRight])

            if viewStore.isTranscribing || viewStore.queuePosition != nil {
              VStack(spacing: .grid(2)) {
                if viewStore.isTranscribing {
                  HStack(spacing: .grid(2)) {
                    ProgressView()
                      .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))

                    Text(viewStore.recording.lastTranscription?.status.message ?? "")
                      .font(.DS.bodyS)
                      .foregroundColor(.DS.Text.accent)
                  }
                } else if let queuePosition = viewStore.queuePosition, let queueTotal = viewStore.queueTotal {
                  Text("In queue: \(queuePosition) of \(queueTotal)")
                    .font(.DS.bodyS)
                    .foregroundColor(.DS.Text.accent)
                }

                Button("Cancel") {
                  viewStore.send(.cancelTranscriptionTapped)
                }.tertiaryButtonStyle()
              }
              .padding(.grid(2))
            } else if !viewStore.recording.isTranscribed {
              Button("Transcribe") {
                viewStore.send(.transcribeTapped)
              }
              .tertiaryButtonStyle()
              .padding(.grid(2))
            }
          }
          .transition(.scale(scale: 0, anchor: .top).combined(with: .opacity).animation(.easeInOut(duration: 0.2)))
        }
      }
    }
    .animation(.easeInOut(duration: 0.3), value: viewStore.state)
    .multilineTextAlignment(.leading)
    .padding(.grid(4))
    .cardStyle(isPrimary: viewStore.mode.isPlaying)
    .offset(y: showItem ? 0 : 200)
    .opacity(showItem ? 1 : 0)
    .animation(
      .spring(response: 0.6, dampingFraction: 0.75)
        .delay(Double(viewStore.index) * 0.15),
      value: showItem
    )
    .alert(
      store: store.scope(state: \.$alert, action: { .alert($0) })
    )
    .onAppear { showItem = true }
    .enableInjection()
  }
}
