import ComposableArchitecture
import DSWaveformImage
import DSWaveformImageViews
import Inject
import SwiftUI

// MARK: - WaveformProgressError

enum WaveformProgressError: Error {
  case audioFileNotFound
}

// MARK: - WaveformProgress

@Reducer
struct WaveformProgress {
  @ObservableState
  struct State: Equatable, Then {
    var fileName = ""
    var progress = 0.0
    var isPlaying = false
    var waveFormImageURL: URL?
  }

  enum Action: Equatable {
    case didAppear
    case waveFormImageCreated(TaskResult<URL>)
    case didTouchAtHorizontalLocation(Double)
  }

  @Dependency(\.storage) var storage: StorageClient

  let waveImageDrawer = WaveformImageDrawer()
  let configuration = Waveform.Configuration(
    size: CGSize(width: 350, height: 120),
    backgroundColor: .clear,
    style: .striped(.init(color: UIColor(Color.DS.Text.base), width: 2, spacing: 4, lineCap: .round)),
    damping: .init(percentage: 0.125, sides: .both),
    scale: DSScreen.scale,
    verticalScalingFactor: 0.95,
    shouldAntialias: true
  )

  var body: some Reducer<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .didAppear:
        guard state.waveFormImageURL == nil else { return .none }

        return Effect.run { [state] send in
          let waveImageURL = storage.waveFileURLWithName(state.fileName + ".waveform.png")
          guard UIImage(contentsOfFile: waveImageURL.path) == nil else {
            await send(.waveFormImageCreated(.success(waveImageURL)))
            return
          }

          let audioURL = storage.audioFileURLWithName(state.fileName)
          guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logs.error("Can't find audio file at \(audioURL.path)")
            await send(.waveFormImageCreated(.failure(WaveformProgressError.audioFileNotFound)))
            return
          }

          let image = try await waveImageDrawer.waveformImage(fromAudioAt: audioURL, with: configuration)
          let data = try image.pngData().require()
          try data.write(to: waveImageURL, options: .atomic)
          await send(.waveFormImageCreated(.success(waveImageURL)))
        } catch: { error, send in
          await send(.waveFormImageCreated(.failure(error)))
        }

      case let .waveFormImageCreated(.success(url)):
        state.waveFormImageURL = url
        return .none

      case let .waveFormImageCreated(.failure(error)):
        logs.error("Failed to create waveform image: \(error)")
        return .none

      case let .didTouchAtHorizontalLocation(horizontal):
        state.progress = horizontal
        return .none
      }
    }
  }
}

// MARK: - WaveformProgressView

@MainActor
struct WaveformProgressView: View {
  @ObserveInjection var inject

  @Perception.Bindable var store: StoreOf<WaveformProgress>

  var body: some View {
    WithPerceptionTracking {
      Rectangle()
        .fill(Color.clear)
        .background {
          waveImageView()
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .grid(1))
        .animation(.linear(duration: 0.1), value: store.progress)
        .onTouchLocationPercent { horizontal, _ in
          store.send(.didTouchAtHorizontalLocation(horizontal))
        }
        .onAppear {
          store.send(.didAppear)
        }
    }
    .enableInjection()
  }

  @ViewBuilder
  private func waveImageView() -> some View {
    ZStack {
      AsyncImage(url: store.waveFormImageURL) { image in
        image
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.DS.Text.subdued)
      } placeholder: {
        ProgressView()
      }.id(store.waveFormImageURL)
      AsyncImage(url: store.waveFormImageURL) { image in
        image
          .resizable()
          .mask(alignment: .leading) {
            GeometryReader { geometry in
              if store.isPlaying {
                Rectangle().frame(width: geometry.size.width * store.progress)
              } else {
                Rectangle()
              }
            }
          }
      } placeholder: {
        ProgressView()
      }.id(store.waveFormImageURL)
    }
  }
}

#if DEBUG
  struct WaveformProgressView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        WaveformProgressView(
          store: Store(initialState: WaveformProgress.State()) {
            WaveformProgress()
          }
        )
      }
    }
  }
#endif
