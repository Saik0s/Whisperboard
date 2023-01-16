//
// Recording.swift
//

import ComposableArchitecture
import SwiftUI

// MARK: - Recording

struct Recording: ReducerProtocol {
  struct CancelID: Hashable {}

  struct State: Equatable {
    var date: Date
    var duration: TimeInterval = 0
    var mode: Mode = .recording
    var url: URL

    enum Mode {
      case recording
      case encoding
    }
  }

  enum Action: Equatable {
    case audioRecorderDidFinish(TaskResult<Bool>)
    case delegate(DelegateAction)
    case finalRecordingTime(TimeInterval)
    case task
    case timerUpdated
    case stopButtonTapped
  }

  enum DelegateAction: Equatable {
    case didFinish(TaskResult<State>)
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.continuousClock) var clock

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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

    case .task:
      return .run { [url = state.url] send in
        async let startRecording: Void = send(
          .audioRecorderDidFinish(
            TaskResult { try await self.audioRecorder.startRecording(url) }
          )
        )
        for await _ in self.clock.timer(interval: .seconds(1)) {
          await send(.timerUpdated)
        }
        await startRecording
      }
      .cancellable(id: CancelID())

    case .timerUpdated:
      state.duration += 1
      return .none
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
            .colorMultiply(Int(viewStore.duration).isMultiple(of: 2) ? Color.Palette.Background.accent : Color.Palette.Text.base)
            .animation(.easeInOut(duration: 0.5), value: viewStore.duration)

          if let formattedDuration = dateComponentsFormatter.string(from: viewStore.duration) {
            Text(formattedDuration)
              .font(.body.monospacedDigit().bold())
              .foregroundColor(Color.Palette.Stroke.base)
          }
        }
      }
      .padding(.horizontal, .grid(13))
      .padding(.vertical, .grid(6))
      .background { Color.black.opacity(0.8).blur(radius: 40) }

      Button { viewStore.send(.stopButtonTapped, animation: .default) } label: {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.Palette.Background.accent)
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
            .colorMultiply(Int(5).isMultiple(of: 2) ? Color.Palette.Background.accent : Color.Palette.Text.base)
            .animation(.easeInOut(duration: 0.5), value: 5)

          if let formattedDuration = dateComponentsFormatter.string(from: 5) {
            Text(formattedDuration)
              .font(.body.monospacedDigit().bold())
              .foregroundColor(Color.Palette.Text.base)
          }
        }
      }
      .padding(.horizontal, .grid(13))
      .padding(.vertical, .grid(6))
      .background { Color.black.opacity(0.7).blur(radius: 40) }

      Button {} label: {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.Palette.Background.accent)
          .shadow(color: .Palette.Shadow.primary, radius: 20)
      }
      .frame(width: 70, height: 70)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.grid(3))
    }
  }
}
