import Common
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - RecordingDetails

@Reducer
struct RecordingDetails {
  enum DisplayMode: Equatable {
    case text, timeline
  }

  struct TimelineItem: Equatable, Identifiable {
    var id: Duration { startTime }
    var text: String
    var startTime: Duration
    var endTime: Duration
  }

  @ObservableState
  struct State: Equatable {
    var recordingCard: RecordingCard.State
    var displayMode: DisplayMode = .text

    @Presents var alert: AlertState<Action.Alert>?

    var timeline: [TimelineItem] {
      recordingCard.recording.transcription?.segments.map {
        TimelineItem(text: $0.text, startTime: Duration.milliseconds($0.startTime), endTime: Duration.milliseconds($0.endTime))
      } ?? []
    }

    var shareAudioFileURL: URL { recordingCard.recording.fileURL }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case recordingCard(RecordingCard.Action)
    case delete
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Hashable {
      case deleteDialogConfirmed
    }

    enum Delegate: Hashable {
      case deleteDialogConfirmed
    }
  }

  var body: some Reducer<State, Action> {
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
        state.alert = AlertState {
          TextState("Confirmation")
        } actions: {
          ButtonState(role: .destructive, action: .deleteDialogConfirmed) {
            TextState("Delete")
          }
        } message: {
          TextState("Are you sure you want to delete this recording?")
        }
        return .none

      case .alert(.presented(.deleteDialogConfirmed)):
        return .send(.delegate(.deleteDialogConfirmed))

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
  }
}

// MARK: - RecordingDetailsView

struct RecordingDetailsView: View {
  private enum Field: Int, CaseIterable {
    case title, text
  }

  @FocusState private var focusedField: Field?

  @Perception.Bindable var store: StoreOf<RecordingDetails>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(2)) {
        VStack(spacing: .grid(2)) {
          TextField(
            "Untitled",
            text: $store.recordingCard.recording.title,
            axis: .vertical
          )
          .focused($focusedField, equals: .title)
          .textStyle(.headline)
          .foregroundColor(.DS.Text.base)

          Text("Created: \(store.recordingCard.recording.date.formatted(date: .abbreviated, time: .shortened))")
            .textStyle(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack(spacing: .grid(2)) {
            CopyButton(store.recordingCard.transcription) {
              Image(systemName: "doc.on.clipboard")
            }

            ShareLink(item: store.recordingCard.transcription) {
              Image(systemName: "paperplane")
            }

            Button { store.send(.recordingCard(.transcribeButtonTapped)) } label: {
              Image(systemName: "arrow.clockwise")
            }.disabled(store.recordingCard.recording.isTranscribing)

            ShareLink(item: store.shareAudioFileURL) {
              Image(systemName: "square.and.arrow.up")
            }

            Button { store.send(.delete) } label: {
              Image(systemName: "trash")
            }

            Spacer()

            Picker(
              "",
              selection: $store.displayMode
            ) {
              Image(systemName: "text.alignleft")
                .tag(RecordingDetails.DisplayMode.text)
              Image(systemName: "list.bullet")
                .tag(RecordingDetails.DisplayMode.timeline)
            }
            .pickerStyle(.segmented)
            .colorMultiply(.DS.Text.accent)
          }.iconButtonStyle()

          if store.recordingCard.recording.isTranscribing || store.recordingCard.queueInfo != nil || !store.recordingCard.recording.isTranscribed {
            TranscriptionControlsView(store: store.scope(state: \.recordingCard, action: \.recordingCard))
          } else if let error = store.recordingCard.recording.transcription?.status.errorMessage {
            Text("Last transcription failed")
              .textStyle(.error)
              .foregroundColor(.DS.Text.error)
            Text(error)
              .textStyle(.error)
              .foregroundColor(.DS.Text.error)
          }

          transcriptionView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        WaveformProgressView(
          store: store.scope(
            state: \.recordingCard.playerControls.waveform,
            action: \.recordingCard.playerControls.view.waveform
          )
        )

        PlayButton(isPlaying: store.recordingCard.playerControls.isPlaying) {
          store.send(.recordingCard(.playerControls(.view(.playButtonTapped))), animation: .spring())
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
      .alert($store.scope(state: \.alert, action: \.alert))
      .background(Color.DS.Background.primary)
    }
  }

  var transcriptionView: some View {
    ScrollView {
      switch store.displayMode {
      case .text:
        Text(store.recordingCard.transcription)
          .foregroundColor(store.recordingCard.recording.isTranscribing ? .DS.Text.subdued : .DS.Text.base)
          .textStyle(.body)
          .lineLimit(nil)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(.vertical, .grid(2))
          .id(1)

      case .timeline:
        LazyVStack {
          ForEach(store.timeline) { item in
            VStack(alignment: .leading, spacing: .grid(1)) {
              Text(
                "[\(item.startTime.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2)))) - \(item.endTime.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2))))]"
              )
              .foregroundColor(.DS.Text.subdued)
              .textStyle(.caption)

              Text(item.text)
                .foregroundColor(.DS.Text.base)
                .textStyle(.body)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .multilineTextAlignment(.leading)
            .padding(.vertical, .grid(2))
          }
        }
        .id(1)
      }
    }
    .scrollAnchor(id: 1, valueToTrack: store.recordingCard.transcription, anchor: .bottom)
    .textSelection(.enabled)
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
  }

  @ViewBuilder
  func transcriptionControls() -> some View {
    if store.recordingCard.recording.isTranscribing || store.recordingCard.queueInfo != nil {
      VStack(spacing: .grid(2)) {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))

        Text(store.recordingCard.recording.isTranscribing
          ? store.recordingCard.recording.transcription?.status.message ?? ""
          : store.recordingCard.queueInfo.map { "In queue: \($0.position) of \($0.total)" } ?? "-")
          .textStyle(.body)

        Button("Cancel") {
          store.send(.recordingCard(.cancelTranscriptionButtonTapped))
        }.tertiaryButtonStyle()
      }
    } else if store.recordingCard.recording.isPaused {
      VStack(spacing: .grid(1)) {
        Text(store.recordingCard.recording.transcription?.status.message ?? "")
          .textStyle(.body)

        HStack {
          Button("Resume") {
            store.send(.recordingCard(.didTapResumeTranscription))
          }.tertiaryButtonStyle()

          Button("Start Over") {
            store.send(.recordingCard(.transcribeButtonTapped))
          }.tertiaryButtonStyle()
        }
      }
    }
  }
}
