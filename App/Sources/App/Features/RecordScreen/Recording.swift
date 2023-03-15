import AppDevUtils
import ComposableArchitecture
import SwiftUI

// MARK: - Recording

public struct Recording: ReducerProtocol {
  struct CancelID: Hashable {}

  public struct State: Equatable {
    var date: Date
    var duration: TimeInterval = 0
    var mode: Mode = .recording
    var url: URL
    var samples: [Float] = []

    enum Mode {
      case recording
      case encoding
    }
  }

  public enum Action: Equatable {
    case audioRecorderDidFinish(TaskResult<Bool>)
    case delegate(DelegateAction)
    case finalRecordingTime(TimeInterval)
    case task
    case recordingStateUpdated(RecordingState)
    case stopButtonTapped
    case pauseButtonTapped
    case continueButtonTapped
    case deleteButtonTapped
  }

  public enum DelegateAction: Equatable {
    case didFinish(TaskResult<State>)
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.continuousClock) var clock

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .audioRecorderDidFinish(.success(true)):
      return .task { [state] in .delegate(.didFinish(.success(state))) }

    case .audioRecorderDidFinish(.success(false)):
      return .task { .delegate(.didFinish(.failure(Failed()))) }

    case let .audioRecorderDidFinish(.failure(error)):
      return .task { .delegate(.didFinish(.failure(error))) }

    case .delegate:
      return .none

    case let .finalRecordingTime(duration):
      state.duration = duration
      return .none

    case .stopButtonTapped:
      state.mode = .encoding
      UIImpactFeedbackGenerator(style: .light).impactOccurred()

      return .run { send in
        if let currentTime = await self.audioRecorder.currentTime() {
          await send(.finalRecordingTime(currentTime))
        }
        await self.audioRecorder.stopRecording()
      }
      .append(EffectTask.cancel(id: CancelID()))
      .eraseToEffect()

    case .task:
      return .run { [url = state.url, audioRecorder] send in
        await audioRecorder.startRecording(url)

        for await recState in await audioRecorder.recordingState() {
          await send(.recordingStateUpdated(recState))
        }
      }
      .cancellable(id: CancelID())

    case let .recordingStateUpdated(.recording(duration, power)):
      state.duration = duration
      state.samples.append(power)
      return .none

    case .recordingStateUpdated:
      return .none

    case .pauseButtonTapped:
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.pauseRecording()
      }

    case .continueButtonTapped:
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.continueRecording()
      }

    case .deleteButtonTapped:
      return .fireAndForget { [audioRecorder] in
        await audioRecorder.stopRecording()
      }
    }
  }
}

// MARK: - RecordingView

struct RecordingView: View {
  let store: StoreOf<Recording>
  @ObservedObject var viewStore: ViewStoreOf<Recording>

  init(store: StoreOf<Recording>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  var body: some View {
    VStack {
      HStack {
        VStack(spacing: 12) {
          Text("Recording")
            .font(.title)
            .colorMultiply(Int(viewStore.duration).isMultiple(of: 2) ? Color.DS.Background.accent : Color.DS.Text.base)
            .animation(.easeInOut(duration: 0.5), value: viewStore.duration)

          if let formattedDuration = dateComponentsFormatter.string(from: viewStore.duration) {
            Text(formattedDuration)
              .font(.body.monospacedDigit().bold())
              .foregroundColor(Color.DS.Stroke.base)
          }
        }
      }
      .padding(.horizontal, .grid(13))
      .padding(.vertical, .grid(6))
      .background { Color.black.opacity(0.8).blur(radius: 40) }

      Button { viewStore.send(.stopButtonTapped, animation: .default) } label: {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.DS.Background.accent)
      }
      .frame(width: 70, height: 70)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.grid(3))
    }
    .task {
      viewStore.send(.task)
    }
  }
}

// MARK: - Whispers_Previews

struct Whispers_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      HStack {
        VStack(spacing: 12) {
          Text("Recording")
            .font(.title)
            .colorMultiply(Int(5).isMultiple(of: 2) ? Color.DS.Background.accent : Color.DS.Text.base)
            .animation(.easeInOut(duration: 0.5), value: 5)

          if let formattedDuration = dateComponentsFormatter.string(from: 5) {
            Text(formattedDuration)
              .font(.body.monospacedDigit().bold())
              .foregroundColor(Color.DS.Text.base)
          }
        }
      }
      .padding(.horizontal, .grid(13))
      .padding(.vertical, .grid(6))
      .background { Color.black.opacity(0.7).blur(radius: 40) }

      Button {} label: {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.DS.Background.accent)
          .shadow(color: .DS.Shadow.primary, radius: 20)
      }
      .frame(width: 70, height: 70)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.grid(3))
    }
  }
}
