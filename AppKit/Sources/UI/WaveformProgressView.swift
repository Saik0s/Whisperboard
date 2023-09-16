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

struct WaveformProgress: ReducerProtocol {
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
    dampening: .init(percentage: 0.125, sides: .both),
    position: .middle,
    scale: DSScreen.scale,
    verticalScalingFactor: 0.95,
    shouldAntialias: true
  )

  var body: some ReducerProtocol<State, Action> {
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
            log.error("Can't find audio file at \(audioURL.path)")
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
        log.error(error)
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

  let store: StoreOf<WaveformProgress>
  @ObservedObject var viewStore: ViewStoreOf<WaveformProgress>

  init(store: StoreOf<WaveformProgress>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .background {
        waveImageView()
      }
      .frame(height: 50)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, .grid(1))
      .animation(.linear(duration: 0.1), value: viewStore.progress)
      .onTouchLocationPercent { horizontal, _ in
        viewStore.send(.didTouchAtHorizontalLocation(horizontal))
      }
      .onAppear {
        viewStore.send(.didAppear)
      }
      .enableInjection()
  }

  @ViewBuilder
  private func waveImageView() -> some View {
    ZStack {
      AsyncImage(url: viewStore.waveFormImageURL) { image in
        image
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.DS.Text.subdued)
      } placeholder: {
        ProgressView()
      }.id(viewStore.waveFormImageURL)
      AsyncImage(url: viewStore.waveFormImageURL) { image in
        image
          .resizable()
          .mask(alignment: .leading) {
            GeometryReader { geometry in
              if viewStore.isPlaying {
                Rectangle().frame(width: geometry.size.width * viewStore.progress)
              } else {
                Rectangle()
              }
            }
          }
      } placeholder: {
        ProgressView()
      }.id(viewStore.waveFormImageURL)
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
