import ComposableArchitecture
import Inject
import SwiftUI
import VariableBlurView

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

    var text: String { recordingCard.isTranscribing ? recordingCard.transcribingProgressText : recordingCard.transcription }
    var timeline: [TimelineItem] {
      recordingCard.recording.transcription?.segments.map {
        TimelineItem(text: $0.text, startTime: Duration.milliseconds($0.startTime), endTime: Duration.milliseconds($0.endTime))
      } ?? []
    }

    var shareAudioFileURL: URL { recordingCard.recording.fileURL }
  }

  enum Action: Equatable {
    case recordingCard(RecordingCard.Action)
    case delete
    case displayModeChanged(DisplayMode)
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
    Scope(state: \.recordingCard, action: /Action.recordingCard) {
      RecordingCard()
    }

    Reduce<State, Action> { state, action in
      switch action {
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

      case let .displayModeChanged(mode):
        state.displayMode = mode
        return .none

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

  @ObserveInjection var inject

  @FocusState private var focusedField: Field?

  @Perception.Bindable var store: StoreOf<RecordingDetails>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(2)) {
        VStack(spacing: .grid(2)) {
          TextField(
            "Untitled",
            text: $store.recordingCard.recording.title.sending(\.recordingCard.titleChanged),
            axis: .vertical
          )
          .focused($focusedField, equals: .title)
          .textStyle(.headline)
          .foregroundColor(.DS.Text.base)

          Text("Created: \(store.recordingCard.recording.date.formatted(date: .abbreviated, time: .shortened))")
            .textStyle(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack(spacing: .grid(2)) {
            CopyButton(store.recordingCard.recording.text) {
              Image(systemName: "doc.on.clipboard")
            }

            ShareLink(item: store.recordingCard.recording.text) {
              Image(systemName: "paperplane")
            }

            Button { store.send(.recordingCard(.transcribeTapped)) } label: {
              Image(systemName: "arrow.clockwise")
            }

            ShareLink(item: store.shareAudioFileURL) {
              Image(systemName: "square.and.arrow.up")
            }

            Button { store.send(.delete) } label: {
              Image(systemName: "trash")
            }

            Spacer()

            Picker(
              "",
              selection: $store.displayMode.sending(\.displayModeChanged)
            ) {
              Image(systemName: "text.alignleft")
                .tag(RecordingDetails.DisplayMode.text)
              Image(systemName: "list.bullet")
                .tag(RecordingDetails.DisplayMode.timeline)
            }
            .pickerStyle(.segmented)
            .colorMultiply(.DS.Text.accent)
          }.iconButtonStyle()

          if !store.recordingCard.recording.isTranscribed
            && !store.recordingCard.recording.isTranscribing
            && !store.recordingCard.recording.isPaused {
            if let error = store.recordingCard.recording.transcriptionErrorMessage {
              Text("Last transcription failed")
                .textStyle(.error)
              Text(error)
                .textStyle(.error)
            }
            Button("Transcribe") {
              store.send(.recordingCard(.transcribeTapped))
            }
            .tertiaryButtonStyle()
            .padding(.grid(4))
          } else {
            transcriptionControls()

            transcriptionView

            // TextField("No transcription", text: store.binding(\.$recordingCard.recordingEnvelop.text), axis: .vertical)
            //   .focused($focusedField, equals: .text)
            //   .lineLimit(nil)
            //   .textFieldStyle(.roundedBorder)
            //   .font(.DS.bodyM)
            //   .foregroundColor(.DS.Text.base)
            //   .background(Color.DS.Background.secondary)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        //      .animation(.easeInOut(duration: 0.3), value: store.recordingCard)

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
    }
    .enableInjection()
  }

  var transcriptionView: some View {
    ScrollView {
      switch store.displayMode {
      case .text:
        Text(store.recordingCard.isTranscribing
          ? store.recordingCard.transcribingProgressText
          : store.recordingCard.transcription)
          .foregroundColor(store.recordingCard.isTranscribing ? .DS.Text.subdued : .DS.Text.base)
          .textStyle(.body)
          .lineLimit(nil)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(.vertical, .grid(2))

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
      }
    }
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
    if store.recordingCard.isTranscribing || store.recordingCard.isInQueue {
      VStack(spacing: .grid(2)) {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .DS.Text.accent))

        Text(store.recordingCard.isTranscribing
          ? store.recordingCard.recording.transcription?.status.message ?? ""
          : "In queue: \(store.recordingCard.queuePosition ?? 0) of \(store.recordingCard.queueTotal ?? 0)")
          .textStyle(.body)

        Button("Cancel") {
          store.send(.recordingCard(.cancelTranscriptionTapped))
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
            store.send(.recordingCard(.transcribeTapped))
          }.tertiaryButtonStyle()
        }
      }
    }
  }
}
