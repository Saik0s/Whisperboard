import AppDevUtils
import ComposableArchitecture
import SwiftUI

// MARK: - Whisper

struct Whisper: ReducerProtocol {
  struct State: Equatable, Identifiable, Codable, Then {
    enum Mode: Equatable, Codable {
      case notPlaying
      case playing(progress: Double)
    }

    var recordingInfo: RecordingInfo
    var mode = Mode.notPlaying

    var id: String { recordingInfo.id }

    init(recordingInfo: RecordingInfo) {
      self.recordingInfo = recordingInfo
    }
  }

  enum Action: Equatable {
    case audioPlayerClient(TaskResult<Bool>)
    case delete
    case playButtonTapped
    case timerUpdated(TimeInterval)
    case titleTextFieldChanged(String)
    case bodyTapped
    case retryTranscription
    case improvedTranscription(String)
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.continuousClock) var clock
  @Dependency(\.storage) var storage

  private enum PlayID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .audioPlayerClient:
      state.mode = .notPlaying
      return .cancel(id: PlayID.self)

    case .delete:
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      return .cancel(id: PlayID.self)

    case .playButtonTapped:
      switch state.mode {
      case .notPlaying:
        state.mode = .playing(progress: 0)

        return .run { [fileName = state.recordingInfo.fileName] send in
          let url = storage.fileURLWithName(fileName)
          async let playAudio: Void = send(
            .audioPlayerClient(TaskResult { try await audioPlayer.play(url) })
          )

          var start: TimeInterval = 0
          for await _ in clock.timer(interval: .milliseconds(500)) {
            start += 0.5
            await send(.timerUpdated(start))
          }

          await playAudio
        }
        .cancellable(id: PlayID.self, cancelInFlight: true)

      case .playing:
        state.mode = .notPlaying
        return .cancel(id: PlayID.self)
      }

    case let .timerUpdated(time):
      switch state.mode {
      case .notPlaying:
        break
      case .playing:
        state.mode = .playing(progress: time / state.recordingInfo.duration)
      }
      return .none

    case let .titleTextFieldChanged(text):
      state.recordingInfo.title = text
      return .none

    case .bodyTapped:
      return .none

    case .retryTranscription:
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      return .none

    case let .improvedTranscription(text):
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      state.recordingInfo.text = text
      return .none
    }
  }
}

extension Whisper.State.Mode {
  var isPlaying: Bool {
    if case .playing = self { return true }
    return false
  }

  var progress: Double? {
    if case let .playing(progress) = self { return progress }
    return nil
  }
}

extension ViewStore where ViewState == Whisper.State {
  var currentTime: TimeInterval {
    state.mode.progress.map { $0 * state.recordingInfo.duration } ?? state.recordingInfo.duration
  }
}

// MARK: - WhisperView

struct WhisperView: View {
  let store: StoreOf<Whisper>
  var isTranscribing = false

  @State var isExpanded = false

  var body: some View {
    WithViewStore(store) { viewStore in
      VStack(spacing: 0) {
        VStack(spacing: .grid(1)) {
          HStack(spacing: .grid(3)) {
            PlayButton(isPlaying: viewStore.mode.isPlaying) {
              viewStore.send(.playButtonTapped)
            }

            VStack(alignment: .leading, spacing: 0) {
              TextField("Untitled",
                        text: viewStore.binding(get: \.recordingInfo.title, send: { .titleTextFieldChanged($0) }))
                .font(.DS.bodyM)
                .foregroundColor(Color.DS.Text.base)
              Text(viewStore.recordingInfo.date.formatted(date: .abbreviated, time: .shortened))
                .font(.DS.date)
                .foregroundColor(Color.DS.Text.subdued)
            }

            dateComponentsFormatter.string(from: viewStore.currentTime).map {
              Text($0)
                .font(.DS.date)
                .foregroundColor(viewStore.mode.isPlaying
                  ? Color.DS.Text.base
                  : Color.DS.Text.subdued)
            }
          }

          WaveformProgressView(
            audioURL: StorageClient.liveValue.fileURLWithName(viewStore.recordingInfo.fileName),
            progress: viewStore.mode.progress ?? 0,
            isPlaying: viewStore.mode.isPlaying
          )
        }

        VStack(spacing: .grid(1)) {
          if viewStore.recordingInfo.isTranscribed {
            HStack {
              CopyButton(text: viewStore.recordingInfo.text)
              ShareButton(text: viewStore.recordingInfo.text)

              Button { viewStore.send(.retryTranscription) } label: {
                Image(systemName: "arrow.clockwise")
                  .foregroundColor(Color.DS.Background.accent)
                  .padding(.grid(1))
              }

              if viewStore.recordingInfo.text.isEmpty == false && UserDefaults.standard.openAIAPIKey?.isEmpty == false {
                ImproveTranscriptionButton(text: viewStore.recordingInfo.text) {
                  viewStore.send(.improvedTranscription($0))
                }
              }

              Spacer()

              Button { viewStore.send(.delete) } label: {
                Image(systemName: "trash")
                  .foregroundColor(Color.DS.Background.accent)
                  .padding(.grid(1))
              }
            }
          }

          if viewStore.recordingInfo.isTranscribed == false, isTranscribing == false {
            Button { viewStore.send(.retryTranscription) } label: {
              Text("Transcribe")
            }
            .buttonStyle(MyButtonStyle())
          } else {
            ExpandableText(viewStore.recordingInfo.text, lineLimit: 2, font: .DS.bodyM, isExpanded: $isExpanded)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .mask {
          LinearGradient.easedGradient(colors: [
            .black,
            isExpanded || !viewStore.recordingInfo.isTranscribed ? .black : .clear,
          ], steps: 2)
        }
        .blur(radius: isTranscribing ? 5 : 0)
        .overlay {
          ActivityIndicator()
            .frame(width: 20, height: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial.opacity(0.7))
            .hidden(isTranscribing == false)
        }
      }
      .padding(.grid(4))
      .cardStyle(isPrimary: viewStore.mode.isPlaying)
      .animation(.easeIn(duration: 0.3), value: viewStore.mode.isPlaying)
    }
  }
}

// MARK: - PlayButton

struct PlayButton: View {
  var isPlaying: Bool
  var action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      Image(systemName: isPlaying ? "pause.circle" : "play.circle")
        .resizable()
        .aspectRatio(1, contentMode: .fit)
        .foregroundColor(.white)
        .animation(.easeInOut(duration: 0.15), value: isPlaying)
    }
    .aspectRatio(1, contentMode: .fit)
    .frame(width: 35, height: 35)
  }
}

extension StringProtocol {
  /// Removes the given delimiter string from both the start and the end of this string if and only if it starts with and ends with the delimiter.
  /// Otherwise returns this string unchanged.
  func removingSurrounding(_ character: Character) -> SubSequence {
    guard count > 1, first == character, last == character else {
      return self[...]
    }
    return dropFirst().dropLast()
  }
}
