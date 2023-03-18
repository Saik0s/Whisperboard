import AppDevUtils
import ComposableArchitecture
import DSWaveformImage
import DSWaveformImageViews
import SwiftUI

// MARK: - Recording

public struct Recording: ReducerProtocol {
  public struct State: Equatable {
    var date: Date
    var duration: TimeInterval = 0
    var mode: Mode = .recording
    var url: URL
    var samples: [Float] = []

    enum Mode {
      case recording
      case encoding
      case paused
      case removing
    }
  }

  public enum Action: Equatable {
    case task
    case delegate(DelegateAction)
    case finalRecordingTime(TimeInterval)
    case stopButtonTapped
    case pauseButtonTapped
    case continueButtonTapped
    case deleteButtonTapped
    case recordingStateUpdated(RecordingState)
  }

  public enum DelegateAction: Equatable {
    case didFinish(TaskResult<State>)
    case didCancel
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.continuousClock) var clock

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .task:
      state.mode = .recording
      UIImpactFeedbackGenerator(style: .light).impactOccurred()

      return .run { [url = state.url, audioRecorder] send in
        await audioRecorder.startRecording(url)

        for await recState in await audioRecorder.recordingState() {
          await send(.recordingStateUpdated(recState))
        }
      }

    case .delegate:
      return .none

    case let .finalRecordingTime(duration):
      state.duration = duration
      return .none

    case .stopButtonTapped:
      state.mode = .encoding
      UIImpactFeedbackGenerator(style: .light).impactOccurred()

      return .run { send in
        await audioRecorder.stopRecording()
        await send(.finalRecordingTime(audioRecorder.currentTime()))
      }

    case .pauseButtonTapped:
      state.mode = .paused
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.pauseRecording()
      }

    case .continueButtonTapped:
      state.mode = .recording
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.continueRecording()
      }

    case .deleteButtonTapped:
      state.mode = .removing
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.removeCurrentRecording()
      }

    case let .recordingStateUpdated(.recording(duration, power)):
      state.duration = duration
      let linear = 1 - pow(10, power / 20)
      state.samples.append(contentsOf: [linear, linear, linear])
      return .none

    case .recordingStateUpdated(.paused):
      state.mode = .paused
      return .none

    case .recordingStateUpdated(.stopped):
      state.mode = .encoding
      return .none

    case let .recordingStateUpdated(.error(error)):
      return .task { .delegate(.didFinish(.failure(error))) }

    case let .recordingStateUpdated(.finished(successfully)):
      return .task { [state] in
        guard state.mode == .encoding else {
          return .delegate(.didCancel)
        }

        if successfully {
          return .delegate(.didFinish(.success(state)))
        } else {
          return .delegate(.didFinish(.failure(Failed())))
        }
      }
    }
  }
}

// MARK: - RecordingView

struct RecordingView: View {
  let store: StoreOf<Recording>
  @ObservedObject var viewStore: ViewStoreOf<Recording>

  var currentTime: String {
    dateComponentsFormatter.string(from: viewStore.duration) ?? ""
  }

  init(store: StoreOf<Recording>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    VStack(spacing: .grid(3)) {
      WaveformLiveCanvas(samples: viewStore.samples, configuration: Waveform.Configuration(
        backgroundColor: .clear,
        style: .striped(.init(color: UIColor(Color.DS.Text.base), width: 2, spacing: 4, lineCap: .round)),
        dampening: .init(percentage: 0.125, sides: .both),
        position: .middle,
        scale: DSScreen.scale,
        verticalScalingFactor: 0.95,
        shouldAntialias: true
      ))
      .frame(maxWidth: .infinity)

      Text(currentTime)
        .font(.DS.titleL)
        .monospaced()
        .foregroundColor(.DS.Text.accent)

      HStack(spacing: .grid(8)) {
        if viewStore.mode == .paused {
          Button { viewStore.send(.deleteButtonTapped, animation: .default) }
          label: { Image(systemName: "multiply").font(.DS.titleL) }
            .frame(width: 50, height: 50)
            .transition(.move(edge: .trailing)
              .combined(with: .opacity))
        }

        ZStack {
          if viewStore.mode == .recording {
            Button { viewStore.send(.pauseButtonTapped, animation: .default) } label: {
              Circle()
                .fill(Color.DS.Background.accent)
                .shadow(color: .DS.Background.accent.opacity(0.5), radius: 20)
                .overlay(Image(systemName: "pause.fill")
                  .font(.DS.titleL)
                  .foregroundColor(.DS.Text.base))
            }
          } else if viewStore.mode == .paused {
            Button { viewStore.send(.continueButtonTapped, animation: .default) } label: {
              Circle()
                .fill(Color.DS.Background.accent)
                .overlay(Image(systemName: "mic")
                  .font(.DS.titleL)
                  .foregroundColor(.DS.Text.base))
            }
          }
        }
        .frame(width: 70, height: 70)
        .zIndex(1)

        if viewStore.mode == .paused {
          Button { viewStore.send(.stopButtonTapped, animation: .default) }
          label: { Image(systemName: "checkmark").font(.DS.titleL) }
            .frame(width: 50, height: 50)
            .transition(.move(edge: .leading)
              .combined(with: .opacity))
        }
      }
      .padding(.grid(3))
    }
    .task {
      await viewStore.send(.task).finish()
    }
  }
}

// MARK: - Whispers_Previews

struct Whispers_Previews: PreviewProvider {
  static var previews: some View {
    RecordingView(store: .init(
      initialState: .init(date: Date(), url: URL(fileURLWithPath: "")),
      reducer: Recording()
    ))
  }
}
