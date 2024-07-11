import Common
import ComposableArchitecture
import Inject
import SwiftUI
import WhisperKit

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
    @Shared var displayMode: DisplayMode

    @Presents var alert: AlertState<Action.Alert>?
    @Presents var actionSheet: RecordingActionsSheet.State?

    var timeline: [TimelineItem] {
      recordingCard.recording.transcription?.segments.map {
        TimelineItem(text: $0.text, startTime: Duration.milliseconds($0.startTimeMS), endTime: Duration.milliseconds($0.endTimeMS))
      } ?? []
    }

    var shareAudioFileURL: URL { recordingCard.recording.fileURL }

    init(recordingCard: RecordingCard.State, displayMode: DisplayMode = .text) {
      self.recordingCard = recordingCard
      _displayMode = Shared(displayMode)
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case recordingCard(RecordingCard.Action)
    case delete
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)
    case actionSheet(PresentationAction<RecordingActionsSheet.Action>)
    case presentActionSheet

    enum Alert: Hashable {
      case deleteDialogConfirmed
    }

    enum Delegate: Hashable {
      case deleteDialogConfirmed
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.recordingCard, action: \.recordingCard) {
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

      case .presentActionSheet:
        state.actionSheet = RecordingActionsSheet.State(
          displayMode: state.$displayMode,
          isTranscribing: state.recordingCard.$recording.isTranscribing,
          transcription: state.recordingCard.$recording.transcription,
          audioFileURL: state.recordingCard.$recording.fileURL
        )
        return .none

      case .actionSheet(.presented(.delete)):
        return .send(.delete)

      case .actionSheet(.presented(.restartTranscription)):
        return .send(.recordingCard(.transcribeButtonTapped))

      case .actionSheet:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.$actionSheet, action: \.actionSheet) {
      RecordingActionsSheet()
    }
  }
}

// MARK: - RecordingDetailsView

struct RecordingDetailsView: View {
  enum Field: Int, CaseIterable {
    case title, text
  }

  @FocusState private var focusedField: Field?
  @Perception.Bindable var store: StoreOf<RecordingDetails>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(4)) {
        headerView
        transcriptionView
        waveformProgressView
        playButtonView
      }
      .background(Color.DS.Background.primary)
      .toolbar {
        ToolbarItem(placement: .keyboard) {
          doneButton
        }
        ToolbarItem(placement: .bottomBar) {
          actionSheetButton
        }
      }

      .alert($store.scope(state: \.alert, action: \.alert))
      .sheet(item: $store.scope(state: \.actionSheet, action: \.actionSheet)) { store in
        RecordingActionsSheetView(store: store)
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
      }
    }
  }

  private var headerView: some View {
    RecordingDetailsHeaderView(
      store: store,
      focusedField: _focusedField
    )
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private var waveformProgressView: some View {
    WaveformProgressView(
      store: store.scope(
        state: \.recordingCard.playerControls.waveform,
        action: \.recordingCard.playerControls.waveform
      )
    )
    .padding(.horizontal, .grid(4))
  }

  private var playButtonView: some View {
    PlayButton(isPlaying: store.recordingCard.playerControls.isPlaying) {
      store.send(.recordingCard(.playerControls(.playButtonTapped)), animation: .bouncy)
    }
  }

  private var doneButton: some View {
    Button("Done") {
      focusedField = nil
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }

  private var transcriptionView: some View {
    ScrollView {
      switch store.displayMode {
      case .text:
        textTranscriptionView

      case .timeline:
        timelineTranscriptionView
      }
    }
    .scrollAnchor(id: 1, valueToTrack: store.recordingCard.transcription, anchor: store.recordingCard.recording.isTranscribing ? .bottom : .zero)
    .applyVerticalEdgeSofteningMask()
  }

  private var textTranscriptionView: some View {
    Text(store.recordingCard.transcription)
      .foregroundColor(store.recordingCard.recording.isTranscribing ? .DS.Text.subdued : .DS.Text.base)
      .textStyle(.body)
      .lineLimit(nil)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(.vertical, .grid(2))
      .padding(.horizontal, .grid(4))
      .id(1)
  }

  private var timelineTranscriptionView: some View {
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
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, .grid(2))
      }
    }
    .padding(.horizontal, .grid(4))
    .id(1)
  }

  private var actionSheetButton: some View {
    Button(action: { store.send(.presentActionSheet) }) {
      Image(systemName: "ellipsis.circle")
        .foregroundColor(.DS.Text.base)
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }
}

// MARK: - RecordingDetailsHeaderView

struct RecordingDetailsHeaderView: View {
  @Perception.Bindable var store: StoreOf<RecordingDetails>
  @FocusState var focusedField: RecordingDetailsView.Field?

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(2)) {
        TextField(
          "Untitled",
          text: $store.recordingCard.recording.title,
          axis: .vertical
        )
        .focused($focusedField, equals: .title)
        .textStyle(.body)

        Text(store.recordingCard.recording.date.formatted(date: .abbreviated, time: .shortened))
          .textStyle(.caption)
          .frame(maxWidth: .infinity, alignment: .leading)

        // if let timings = store.recordingCard.recording.transcription?.timings {
        //   VStack(alignment: .leading, spacing: .grid(1)) {
        //     LabeledContent {
        //       Text(String(format: "%.2f", timings.tokensPerSecond))
        //     } label: {
        //       Label("Tokens/Second", systemImage: "speedometer")
        //     }

        //     LabeledContent {
        //       Text(String(format: "%.2f", timings.fullPipeline))
        //     } label: {
        //       Label("Full Pipeline (s)", systemImage: "clock")
        //     }
        //   }
        //   .textStyle(.footnote)
        // }

        if let error = store.recordingCard.recording.transcription?.status.errorMessage {
          Text("Last transcription failed")
            .textStyle(.error)
          
          Text(error)
            .textStyle(.error)
        } else {
          TranscriptionControlsView(store: store.scope(state: \.recordingCard, action: \.recordingCard), queueInfo: nil)
        }
      }
      .padding(.horizontal, .grid(4))
    }
  }
}
