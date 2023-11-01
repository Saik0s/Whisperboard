
import ComposableArchitecture
import Inject
import SwiftUI
import VariableBlurView

// MARK: - RecordingDetails

struct RecordingDetails: ReducerProtocol {
  struct State: Equatable {
    var recordingCard: RecordingCard.State

    var shareAudioFileURL: URL { recordingCard.recording.fileURL }
  }

  enum Action: Equatable {
    case recordingCard(action: RecordingCard.Action)
    case delete
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.recordingCard, action: /Action.recordingCard) {
      RecordingCard()
    }

    Reduce<State, Action> { _, action in
      switch action {
      case .recordingCard:
        return .none

      case .delete:
        return .none
      }
    }
  }
}

// MARK: - RecordingDetailsView

struct RecordingDetailsView: View {
  private enum Field: Int, CaseIterable {
    case title, text
  }

  @ObserveInjection var inject

  @FocusState private var focusedField: Field?

  let store: StoreOf<RecordingDetails>
  @ObservedObject var viewStore: ViewStore<RecordingDetails.State, RecordingDetails.Action>

  init(store: StoreOf<RecordingDetails>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  var body: some View {
    VStack(spacing: .grid(2)) {
      VStack(spacing: .grid(2)) {
        TextField(
          "Untitled",
          text: viewStore.binding(
            get: { $0.recordingCard.recording.title },
            send: { RecordingDetails.Action.recordingCard(action: .titleChanged($0)) }
          ),
          axis: .vertical
        )
        .focused($focusedField, equals: .title)
        .textStyle(.headline)
        .foregroundColor(.DS.Text.base)

        Text("Created: \(viewStore.recordingCard.recording.date.formatted(date: .abbreviated, time: .shortened))")
          .textStyle(.caption)
          .frame(maxWidth: .infinity, alignment: .leading)

        if viewStore.recordingCard.recording.isTranscribed == false
          && !viewStore.recordingCard.recording.isTranscribing {
          if let error = viewStore.recordingCard.recording.lastTranscriptionErrorMessage {
            Text("Last transcription failed")
              .textStyle(.error)
            Text(error)
              .textStyle(.error)
          }
          Button("Transcribe") {
            viewStore.send(.recordingCard(action: .transcribeTapped))
          }
          .tertiaryButtonStyle()
          .padding(.grid(4))
        } else {
          if !viewStore.recordingCard.isTranscribing {
            HStack(spacing: .grid(2)) {
              CopyButton(viewStore.recordingCard.recording.text) {
                Image(systemName: "doc.on.clipboard")
              }

              ShareLink(item: viewStore.recordingCard.recording.text) {
                Image(systemName: "paperplane")
              }

              Button { viewStore.send(.recordingCard(action: .transcribeTapped)) } label: {
                Image(systemName: "arrow.clockwise")
              }

              ShareLink(item: viewStore.shareAudioFileURL) {
                Image(systemName: "square.and.arrow.up")
              }

              Button { viewStore.send(.delete) } label: {
                Image(systemName: "trash")
              }

              Spacer()
            }.iconButtonStyle()
          }

          if viewStore.recordingCard.isTranscribing || viewStore.recordingCard.isInQueue {
            VStack(spacing: .grid(2)) {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))

              Text(viewStore.recordingCard.isTranscribing
                ? viewStore.recordingCard.recording.lastTranscription?.status.message ?? ""
                : "In queue: \(viewStore.recordingCard.queuePosition ?? 0) of \(viewStore.recordingCard.queueTotal ?? 0)")
                .textStyle(.body)

              Button("Cancel") {
                viewStore.send(.recordingCard(action: .cancelTranscriptionTapped))
              }.tertiaryButtonStyle()
            }
          }

          ScrollView {
            Text(viewStore.recordingCard.isTranscribing
              ? viewStore.recordingCard.transcribingProgressText
              : viewStore.recordingCard.transcription)
              .foregroundColor(viewStore.recordingCard.isTranscribing ? .DS.Text.subdued : .DS.Text.base)
              .textStyle(.body)
              .lineLimit(nil)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
              .padding(.vertical, .grid(2))
          }
          .mask {
            LinearGradient(
              stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.02),
                .init(color: .black, location: 0.98),
                .init(color: .clear, location: 1),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          }
          .offset(x: 0, y: -8)

          // TextField("No transcription", text: viewStore.binding(\.$recordingCard.recordingEnvelop.text), axis: .vertical)
          //   .focused($focusedField, equals: .text)
          //   .lineLimit(nil)
          //   .textFieldStyle(.roundedBorder)
          //   .font(.DS.bodyM)
          //   .foregroundColor(.DS.Text.base)
          //   .background(Color.DS.Background.secondary)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      //      .animation(.easeInOut(duration: 0.3), value: viewStore.recordingCard)

      WaveformProgressView(
        store: store.scope(
          state: { $0.recordingCard.waveform },
          action: { .recordingCard(action: .waveform($0)) }
        )
      )

      PlayButton(isPlaying: viewStore.recordingCard.mode.isPlaying) {
        viewStore.send(.recordingCard(action: .playButtonTapped), animation: .spring())
      }
    }
    .padding(.grid(4))
    .toolbar {
      ToolbarItem(placement: .keyboard) {
        Button("Done") {
          focusedField = nil
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .enableInjection()
  }
}

#if DEBUG

  struct RecordingDetailsView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordingDetailsView(
          store: Store(
            initialState: RecordingDetails.State(recordingCard: .init(recording: .mock, index: 0)),
            reducer: { RecordingDetails() }
          )
        )
      }
    }
  }
#endif
