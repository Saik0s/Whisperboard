//
// Whisper.swift
//

import ComposableArchitecture
import SwiftUI

// MARK: - Whisper

struct Whisper: ReducerProtocol {
  struct State: Equatable, Identifiable, Codable, Then {
    var date: Date
    var duration: TimeInterval
    var mode = Mode.notPlaying
    var title = ""
    var fileName: String
    var text: String = ""
    var isTranscribed = false

    var id: String { fileName }

    enum Mode: Equatable, Codable {
      case notPlaying
      case playing(progress: Double)

      var isPlaying: Bool {
        if case .playing = self { return true }
        return false
      }

      var progress: Double? {
        if case let .playing(progress) = self { return progress }
        return nil
      }
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

        return .run { [fileName = state.fileName] send in
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
        state.mode = .playing(progress: time / state.duration)
      }
      return .none

    case let .titleTextFieldChanged(text):
      state.title = text
      return .none

    case .bodyTapped:
      return .none

    case .retryTranscription:
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      return .none

    case let .improvedTranscription(text):
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      state.text = text
      return .none
    }
  }
}

extension ViewStore where ViewState == Whisper.State {
  var currentTime: TimeInterval {
    state.mode.progress.map { $0 * state.duration } ?? state.duration
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
                        text: viewStore.binding(get: \.title, send: { .titleTextFieldChanged($0) }))
                .font(.DS.bodyM)
                .foregroundColor(Color.Palette.Text.base)
              Text(viewStore.date.formatted(date: .abbreviated, time: .shortened))
                .font(.DS.date)
                .foregroundColor(Color.Palette.Text.subdued)
            }

            dateComponentsFormatter.string(from: viewStore.currentTime).map {
              Text($0)
                .font(.DS.date)
                .foregroundColor(viewStore.mode.isPlaying
                  ? Color.Palette.Text.base
                  : Color.Palette.Text.subdued)
            }
          }

          WaveformProgressView(
            audioURL: Storage.liveValue.fileURLWithName(viewStore.fileName),
            progress: viewStore.mode.progress ?? 0,
            isPlaying: viewStore.mode.isPlaying
          )
        }

        VStack(spacing: .grid(1)) {
          HStack {
            CopyButton(text: viewStore.text)
            ShareButton(text: viewStore.text)

            Button { viewStore.send(.retryTranscription) } label: {
              Image(systemName: "arrow.clockwise")
                .foregroundColor(Color.Palette.Background.accent)
                .padding(.grid(1))
            }

            if viewStore.text.isEmpty == false && UserDefaults.standard.openAIAPIKey?.isEmpty == false {
              ImproveTranscriptionButton(text: viewStore.text) {
                viewStore.send(.improvedTranscription($0))
              }
            }

            Spacer()

            Button { viewStore.send(.delete) } label: {
              Image(systemName: "trash")
                .foregroundColor(Color.Palette.Background.accent)
                .padding(.grid(1))
            }
          }

          ExpandableText(viewStore.text, lineLimit: 2, font: .DS.bodyM, isExpanded: $isExpanded)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .mask {
          LinearGradient.easedGradient(colors: [.black, isExpanded ? .black : .clear], steps: 2)
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

// MARK: - ImproveTranscriptionButton

@MainActor
struct ImproveTranscriptionButton: View {
  struct TextCompletion: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage

    struct Choice: Codable {
      let text: String
      let index: Int
      let logprobs: String?
      let finish_reason: String
    }

    struct Usage: Codable {
      let prompt_tokens: Int
      let completion_tokens: Int
      let total_tokens: Int
    }
  }

  var text: String
  var callback: (String) -> Void

  @State var isLoading = false

  var body: some View {
    Button { action() } label: {
      Image(systemName: "wand.and.stars")
        .foregroundColor(Color.Palette.Background.accent)
        .padding(.grid(1))
    }
    .disabled(isLoading)
    .overlay {
      ActivityIndicator()
        .hidden(isLoading == false)
    }
  }

  private func action() {
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()

    guard let apiKey = UserDefaults.standard.openAIAPIKey else { return }

    var prompt =
      "Please correct any errors in the following transcript, which was generated by Whisper ASR. The text may contain incorrect spelling, grammar, or punctuation errors. Please make sure the corrected text is still coherent and makes sense in context.\nInput: "
    prompt += "\"\(text)\"\n"
    let apiURL = URL(string: "https://api.openai.com/v1/completions")!
    let model = "text-davinci-003"
    let temperature = 0
    let maxTokens = 1000
    let topP: Float = 1
    let frequencyPenalty = 0
    let presencePenalty = 0

    var request = URLRequest(url: apiURL)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"

    let body: [String: Any] = [
      "model": model,
      "prompt": prompt,
      "temperature": temperature,
      "max_tokens": maxTokens,
      "top_p": topP,
      "frequency_penalty": frequencyPenalty,
      "presence_penalty": presencePenalty,
      "stop": "---",
    ]

    Task {
      isLoading = true
      do {
        log(body)

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await URLSession.shared.data(for: request)
        let data = response.0

        log(String(data: data, encoding: .utf8) ?? "no data")

        do {
          let decoder = JSONDecoder()
          let textCompletion = try decoder.decode(TextCompletion.self, from: data)
          if let generatedText = textCompletion.choices.first?.text {
            callback(String(generatedText.trimmingPrefix("\nOutput: ").removingSurrounding("\"")))
          } else {
            log("No choices")
          }
        } catch {
          log(error)

          if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
             let error = json["error"] as? [String: Any],
             let errorMessage = error["message"] as? String {
            log("Error message: \(errorMessage)")
          } else {
            log("Error parsing response")
          }
        }
      } catch {
        log(error)
      }
      isLoading = false
    }
  }
}

extension StringProtocol {
  /// Removes the given delimiter string from both the start and the end of this string if and only if it starts with and ends with the delimiter. Otherwise returns this string unchanged.
  func removingSurrounding(_ character: Character) -> SubSequence {
    guard count > 1, first == character, last == character else {
      return self[...]
    }
    return dropFirst().dropLast()
  }
}