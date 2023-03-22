import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingDetails

public struct RecordingDetails: ReducerProtocol {
  public struct State: Equatable {
    @BindingState var recordingCard: RecordingCard.State
  }

  public enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case recordingCard(action: RecordingCard.Action)
    case transcribeTapped
    case retryTranscriptionTapped
    case improvedTranscription(String)
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

      case .transcribeTapped:
        return .send(.recordingCard(action: .transcribeTapped))

      case .retryTranscriptionTapped:
        return .send(.transcribeTapped)

      case let .improvedTranscription(text):
        state.recordingCard.recordingInfo.text = text
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

  public init(store: StoreOf<RecordingDetails>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      VStack(spacing: .grid(2)) {
        TextField("Untitled", text: viewStore.binding(\.$recordingCard.recordingInfo.title))
          .focused($focusedField, equals: .title)
          .font(.DS.titleXL)
          .foregroundColor(.DS.Text.base)

        Text("Created: \(viewStore.recordingCard.recordingInfo.date.formatted(date: .abbreviated, time: .shortened))")
          .font(.DS.captionS)
          .foregroundColor(.DS.Text.subdued)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer()

        VStack(spacing: .grid(2)) {
          Text("Transcription:")
            .font(.DS.headlineS)
            .foregroundColor(.DS.Text.subdued)
            .frame(maxWidth: .infinity, alignment: .leading)

          if viewStore.recordingCard.recordingInfo.isTranscribed == false {
            if viewStore.recordingCard.isTranscribing {
              ProgressView()
                .padding(.grid(4))
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
          } else {
            HStack(spacing: .grid(2)) {
              CopyButton(text: viewStore.recordingCard.recordingInfo.text)
              ShareButton(text: viewStore.recordingCard.recordingInfo.text)

              if !viewStore.recordingCard.isTranscribing {
                Button { viewStore.send(.retryTranscriptionTapped) } label: {
                  Image(systemName: "arrow.clockwise")
                    .padding(.grid(1))
                }
              }

              // if viewStore.recordingCard.recordingInfo.text.isEmpty == false && viewStore.recordingCard.isTranscribing == false {
              //   ImproveTranscriptionButton(text: viewStore.recordingCard.recordingInfo.text) {
              //     viewStore.send(.improvedTranscription($0))
              //   }
              // }

              Spacer()
            }
            .foregroundColor(Color.DS.Background.accent)
            .font(.DS.titleM)

            ScrollView {
              Text(viewStore.recordingCard.recordingInfo.text)
                .font(.DS.bodyL)
                .foregroundColor(viewStore.recordingCard.isTranscribing ? .DS.Text.subdued : .DS.Text.base)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)

              if viewStore.recordingCard.isTranscribing {
                ProgressView()
              }
            }

            // TextField("No transcription", text: viewStore.binding(\.$recordingCard.recordingInfo.text), axis: .vertical)
            //   .focused($focusedField, equals: .text)
            //   .lineLimit(nil)
            //   .textFieldStyle(.roundedBorder)
            //   .font(.DS.bodyM)
            //   .foregroundColor(.DS.Text.base)
            //   .background(Color.DS.Background.secondary)
          }
        }
        .frame(maxHeight: .infinity, alignment: .top)

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

        Spacer()
      }
      .padding(.grid(4))
      .screenRadialBackground()
      .toolbar {
        ToolbarItem(placement: .keyboard) {
          Button("Done") {
            focusedField = nil
          }
          .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .navigationBarTitleDisplayMode(.inline)
    .enableInjection()
  }
}

#if DEBUG
  struct RecordingDetailsView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        RecordingDetailsView(
          store: Store(
            initialState: RecordingDetails.State(recordingCard: .init(recordingInfo: .mock)),
            reducer: RecordingDetails()
          )
        )
      }
    }
  }
#endif
