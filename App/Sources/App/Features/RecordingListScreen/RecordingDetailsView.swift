import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingDetails

public struct RecordingDetails: ReducerProtocol {
  public struct State: Equatable {
    @BindingState var recordingCard: RecordingCard.State
    @BindingState var shareAudioFileURL: URL?
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case recordingCard(action: RecordingCard.Action)
    case delete
    case shareAudio
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient
  @Dependency(\.storage) var storage: StorageClient

  public var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Scope(state: \.recordingCard, action: /Action.recordingCard) {
      RecordingCard()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .binding:
        return .none

      case .recordingCard:
        return .none

      case .delete:
        return .none

      case .shareAudio:
        state.shareAudioFileURL = storage.audioFileURLWithName(state.recordingCard.recordingEnvelop.fileName)
        return .none
      }
    }
  }
}

// MARK: - RecordingDetailsView

public struct RecordingDetailsView: View {
  private enum Field: Int, CaseIterable {
    case title, text
  }

  @ObserveInjection var inject

  @FocusState private var focusedField: Field?

  let store: StoreOf<RecordingDetails>
  @ObservedObject var viewStore: ViewStoreOf<RecordingDetails>

  public init(store: StoreOf<RecordingDetails>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  public var body: some View {
    VStack(spacing: .grid(2)) {
      TextField(
        "Untitled",
        text: viewStore.binding(
          get: { $0.recordingCard.recordingEnvelop.title },
          send: { RecordingDetails.Action.recordingCard(action: .titleChanged($0)) }
        )
      )
      .focused($focusedField, equals: .title)
      .font(.DS.titleXL)
      .minimumScaleFactor(0.01)
      .foregroundColor(.DS.Text.base)

      Text("Created: \(viewStore.recordingCard.recordingEnvelop.date.formatted(date: .abbreviated, time: .shortened))")
        .font(.DS.captionS)
        .foregroundColor(.DS.Text.subdued)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text("Transcription:")
        .font(.DS.headlineS)
        .foregroundColor(.DS.Text.subdued)
        .frame(maxWidth: .infinity, alignment: .leading)

      if viewStore.recordingCard.recordingEnvelop.isTranscribed == false
        && viewStore.recordingCard.recordingEnvelop.transcriptionState?.isTranscribing != true {
        PrimaryButton("Transcribe") {
          viewStore.send(.recordingCard(action: .transcribeTapped))
        }.padding(.grid(4))

      } else {
        if !viewStore.recordingCard.isTranscribing {
          HStack(spacing: .grid(2)) {
            CopyButton(viewStore.recordingCard.recordingEnvelop.text) {
              Image(systemName: "doc.on.clipboard")
            }

            ShareButton(viewStore.recordingCard.recordingEnvelop.text) {
              Image(systemName: "paperplane")
            }

            Button { viewStore.send(.recordingCard(action: .transcribeTapped)) } label: {
              Image(systemName: "arrow.clockwise").padding(.grid(1))
            }

            Spacer()
          }.iconButtonStyle()
        }

        ScrollView {
          Text(viewStore.recordingCard.isTranscribing
            ? viewStore.recordingCard.transcribingProgressText
            : viewStore.recordingCard.recordingEnvelop.text)
            .font(.DS.bodyL)
            .foregroundColor(viewStore.recordingCard.isTranscribing ? .DS.Text.subdued : .DS.Text.base)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)

          if viewStore.recordingCard.isTranscribing {
            ProgressView()
          }
        }

        // TextField("No transcription", text: viewStore.binding(\.$recordingCard.recordingEnvelop.text), axis: .vertical)
        //   .focused($focusedField, equals: .text)
        //   .lineLimit(nil)
        //   .textFieldStyle(.roundedBorder)
        //   .font(.DS.bodyM)
        //   .foregroundColor(.DS.Text.base)
        //   .background(Color.DS.Background.secondary)
      }

      Spacer()

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
    .screenRadialBackground()
    .shareSheet(item: viewStore.binding(\.$shareAudioFileURL))
    .toolbar {
      ToolbarItem(placement: .keyboard) {
        Button("Done") {
          focusedField = nil
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .navigationBarItems(
      trailing: HStack(spacing: .grid(4)) {
        Button { viewStore.send(.shareAudio) } label: {
          Image(systemName: "square.and.arrow.up")
        }

        Button { viewStore.send(.delete) } label: {
          Image(systemName: "trash")
        }
      }.secondaryIconButtonStyle()
    )
    .scrollContentBackground(.hidden)
    .navigationBarTitleDisplayMode(.inline)
    .task { await viewStore.send(.recordingCard(action: .task)).finish() }
    .enableInjection()
  }
}

#if DEBUG
  struct RecordingDetailsView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordingDetailsView(
          store: Store(
            initialState: RecordingDetails.State(recordingCard: .init(recordingEnvelop: .mock)),
            reducer: RecordingDetails()
          )
        )
      }
    }
  }
#endif
