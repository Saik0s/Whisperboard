import AudioProcessing
import Common
import ComposableArchitecture
import DSWaveformImage
import DSWaveformImageViews
import Foundation
import Inject
import Popovers
import SwiftUI

// MARK: - RecordingControls

@Reducer
struct RecordingControls {
  @ObservableState
  struct State: Equatable {
    enum TranscriptionViewMode {
      case simple
      case technical
    }

    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }

    var alert: AlertState<Action>?
    var recording: Recording.State?
    var audioRecorderPermission = RecorderPermission.undetermined
    var isGoToNewRecordingPopupPresented = false
    var isLiveTranscriptionEnabled = false
    var transcriptionViewMode = TranscriptionViewMode.simple
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case recording(Recording.Action)
    case recordPermissionResponse(Bool)
    case recordButtonTapped
    case openSettingsButtonTapped
    case goToNewRecordingButtonTapped
  }

  @Dependency(\.audioSession.requestRecordPermission) var requestRecordPermission
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.date) var date
  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid

  enum CancelID: Hashable { case recording }

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce<State, Action> { state, action in
      switch action {
      case .recordButtonTapped:
        switch state.audioRecorderPermission {
        case .undetermined:
          return .run { send in
            await send(.recordPermissionResponse(requestRecordPermission()))
          }

        case .denied:
          state.alert = micPermissionAlert
          return .none

        case .allowed:
          return startRecording(&state)
        }

      case .recording(.delegate(.didCancel)):
        state.recording = nil
        return .cancel(id: CancelID.recording)

      case .recording(.delegate(.didFinish(.success))):
        state.recording = nil
        return .cancel(id: CancelID.recording)

      case .recording(.delegate(.didFinish(.failure))):
        state.recording = nil
        return .cancel(id: CancelID.recording)

      case .recording:
        return .none

      case let .recordPermissionResponse(permission):
        state.audioRecorderPermission = permission ? .allowed : .denied
        if permission {
          return startRecording(&state)
        } else {
          state.alert = micPermissionAlert
          return .none
        }

      case .openSettingsButtonTapped:
        return .run { _ in
          await openSettings()
        }

      case .binding(.set(\.isGoToNewRecordingPopupPresented, true)):
        return .run { send in
          try await clock.sleep(for: .seconds(5))
          await send(.binding(.set(\.isGoToNewRecordingPopupPresented, false)))
        }

      case .goToNewRecordingButtonTapped:
        state.isGoToNewRecordingPopupPresented = false
        return .none

      case .binding:
        return .none
      }
    }
    .ifLet(\.recording, action: \.recording) { Recording() }
  }

  private func startRecording(_ state: inout State) -> Effect<Action> {
    state.recording = Recording.State(recordingInfo: RecordingInfo(id: uuid().uuidString, title: "New Recording", date: date.now, duration: 0))
    return .run { [state] send in
      await send(.recording(.startRecording(withLiveTranscription: state.isLiveTranscriptionEnabled)))
    }.cancellable(id: CancelID.recording, cancelInFlight: true)
  }

  private var micPermissionAlert: AlertState<Action> {
    AlertState(
      title: TextState("Permission is required to record voice."),
      message: TextState("Please enable microphone access in Settings."),
      primaryButton: .default(TextState("Open Settings"), action: .send(.openSettingsButtonTapped)),
      secondaryButton: .cancel(TextState("Cancel"))
    )
  }
}

// MARK: - RecordingControlsView

struct RecordingControlsView: View {
  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<RecordingControls>
  @Environment(NamespaceContainer.self) var namespace

  var currentTime: String {
    (store.recording?.recordingInfo.duration).flatMap {
      dateComponentsFormatter.string(from: $0)
    } ?? ""
  }

  var bufferEnergy: [Float] {
    store.recording?.samples ?? []
  }

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(3)) {
        if store.isLiveTranscriptionEnabled {
          if let recording = store.recording {
            liveTranscriptionView(recording)
          }
        } else {
          GeometryReader { geometry in
            WithPerceptionTracking {
              ScrollView(.horizontal) {
                LazyHStack(spacing: 1) {
                  let startIndex = max(bufferEnergy.count - 300, 0)
                  ForEach(bufferEnergy[startIndex...], id: \.self) { energy in
                    RoundedRectangle(cornerRadius: 2)
                      .fill(energy > Float(0.3) ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                      .frame(width: 2, height: CGFloat(energy) * geometry.size.height)
                      .transition(.scale(scale: 0).combined(with: .opacity).animation(.bouncy))
                  }
                }.id(1)
              }
              .scrollAnchor(id: 1, valueToTrack: bufferEnergy.count, anchor: .trailing)
              .frame(height: 24)
              .scrollIndicators(.never)
            }
          }
          .frame(maxHeight: .infinity)

//          WaveformLiveCanvas(samples: store.recording?.samples ?? [], configuration: Waveform.Configuration(
//            backgroundColor: .clear,
//            style: .striped(.init(color: UIColor(Color.DS.Text.base), width: 2, spacing: 4, lineCap: .round)),
//            damping: .init(percentage: 0.125, sides: .both),
//            scale: DSScreen.scale,
//            verticalScalingFactor: 0.95,
//            shouldAntialias: true
//          ))
//          .frame(maxWidth: .infinity)
        }
        if store.recording == nil {
          Toggle("Live Transcription", systemImage: "text.bubble", isOn: $store.isLiveTranscriptionEnabled)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        Text(currentTime)
          .foregroundColor(.DS.Text.accent)
          .textStyle(.navigationTitle)
          .monospaced()

        HStack(spacing: .grid(8)) {
          if store.recording?.mode == .paused {
            Button { store.send(.recording(.deleteButtonTapped), animation: .showHide()) }
              label: {
                Image(systemName: "multiply")
                  .textStyle(.navigationTitle)
                  .frame(width: 50, height: 50)
                  .containerShape(Rectangle())
              }
              .transition(.move(edge: .trailing).combined(with: .opacity))
          }

          ZStack {
            if store.recording?.mode == .recording {
              Button { store.send(.recording(.pauseButtonTapped), animation: .showHide()) } label: {
                Circle()
                  .fill(RadialGradient.accent)
                  .shadow(color: .DS.Background.accent.opacity(0.5), radius: 20)
                  .overlay(Image(systemName: "pause.fill").textStyle(.headline))
              }
              .recordButtonStyle()
              .matchedGeometryEffect(id: "mic", in: namespace.namespace)
            } else if store.recording?.mode == .paused {
              Button { store.send(.recording(.continueButtonTapped), animation: .showHide()) } label: {
                Circle()
                  .fill(RadialGradient.accent)
                  .overlay(Image(systemName: "mic").textStyle(.headline))
              }
              .recordButtonStyle()
              .matchedGeometryEffect(id: "mic", in: namespace.namespace)
            } else {
              RecordButton(permission: store.audioRecorderPermission) {
                store.send(.recordButtonTapped, animation: .showHide())
              } settingsAction: {
                store.send(.openSettingsButtonTapped)
              }
            }
          }
          .frame(width: 70, height: 70)

          if store.recording?.mode == .paused {
            Button { store.send(.recording(.saveButtonTapped), animation: .showHide()) }
              label: {
                Image(systemName: "checkmark")
                  .textStyle(.navigationTitle)
                  .frame(width: 50, height: 50)
                  .containerShape(Rectangle())
              }
              .transition(.move(edge: .leading).combined(with: .opacity))
          }
        }
        .padding(.horizontal, .grid(3))
        .popover(
          present: $store.isGoToNewRecordingPopupPresented,
          attributes: {
            $0.position = .absolute(originAnchor: .top, popoverAnchor: .bottom)
            $0.presentation = .init(animation: .hardShowHide(), transition: .move(edge: .bottom).combined(with: .opacity))
            $0.dismissal = .init(
              animation: .hardShowHide(),
              transition: .move(edge: .bottom).combined(with: .opacity),
              mode: [.dragDown, .tapOutside]
            )
          }
        ) {
          VStack(spacing: .grid(4)) {
            Text("View the new recording?")
              .textStyle(.label)
              .foregroundColor(.DS.Text.base)

            Button("View Recording") {
              store.send(.goToNewRecordingButtonTapped)
            }.secondaryButtonStyle()
          }
          .padding(.grid(3))
          .cardStyle()
          .enableInjection()
        }
      }
    }
    .enableInjection()
  }

  @ViewBuilder
  private func liveTranscriptionView(_ recording: Recording.State) -> some View {
    VStack(spacing: .grid(2)) {
      switch recording.liveTranscriptionState {
      case let .modelLoading(progress):
        LabeledContent {
          Text("\(Int(progress * 100)) %")
            .foregroundColor(.DS.Text.base)
            .textStyle(.body)
        } label: {
          Label("Model Loading", systemImage: "info.circle")
            .foregroundColor(.DS.Text.base)
            .textStyle(.body)
        }
        .padding(.grid(4))
        .cardStyle()
        .fixedSize(horizontal: true, vertical: true)

      case let .transcribing(text):
        ScrollView(showsIndicators: false) {
          Text(recording.recordingInfo.text)
            .foregroundColor(.DS.Text.base)
            .textStyle(.body)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .grid(2))
            .padding(.horizontal, .grid(4))

          #if DEBUG
            Text(text)
              .multilineTextAlignment(.leading)
              .textStyle(.body)
              .frame(maxWidth: .infinity, alignment: .leading)
          #endif
        }

      case .none:
        EmptyView()
      }

      Spacer()
    }
  }
}
