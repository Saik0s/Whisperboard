import AppDevUtils
import ComposableArchitecture
import DSWaveformImage
import DSWaveformImageViews
import Inject
import SwiftUI

// MARK: - WaveformProgress

public struct WaveformProgress: ReducerProtocol {
  public struct State: Equatable, Then {
    var fileName = ""
    var progress = 0.0
    var isPlaying = false
    var waveFormImageURL: URL?
  }

  public enum Action: Equatable {
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

  public var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .didAppear:
        guard state.waveFormImageURL == nil else {
          return .none
        }

        let waveImageURL = storage.waveFileURLWithName(state.fileName + ".waveform.png")
        guard UIImage(contentsOfFile: waveImageURL.path) == nil else {
          state.waveFormImageURL = waveImageURL
          return .none
        }

        let audioURL = storage.audioFileURLWithName(state.fileName)
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
          log.error("Can't find audio file at \(audioURL.path)")
          return .none
        }

        return .task {
          let image = try await waveImageDrawer.waveformImage(fromAudioAt: audioURL, with: configuration)
          let data = try image.pngData().require()
          try data.write(to: waveImageURL, options: .atomic)
          return .waveFormImageCreated(.success(waveImageURL))
        } catch: { error in
          log.error(error)
          return .waveFormImageCreated(.failure(error))
        }

      case let .waveFormImageCreated(.success(url)):
        state.waveFormImageURL = url
        return .none

      case let .waveFormImageCreated(.failure(error)):
        log.error(error)
        return .none

      case let .didTouchAtHorizontalLocation(horizontal):
        log.debug(horizontal)
        state.progress = horizontal
        return .none
      }
    }
  }
}

// MARK: - WaveformProgressView

@MainActor
public struct WaveformProgressView: View {
  @ObserveInjection var inject

  let store: StoreOf<WaveformProgress>
  @ObservedObject var viewStore: ViewStoreOf<WaveformProgress>

  public init(store: StoreOf<WaveformProgress>) {
    self.store = store
    viewStore = ViewStore(store)
  }

  public var body: some View {
    ZStack {
      waveImageView()
        .onTouchLocationPercent { horizontal, _ in
          viewStore.send(.didTouchAtHorizontalLocation(horizontal))
        }
        .padding(.horizontal, .grid(1))
        .frame(height: 50)
        .frame(maxWidth: .infinity)
    }
    .animation(.linear(duration: 0.1), value: viewStore.progress)
    .onAppear {
      viewStore.send(.didAppear)
    }
    .enableInjection()
  }

  @ViewBuilder
  private func waveImageView() -> some View {
    if let imageURL = viewStore.waveFormImageURL,
       let image = UIImage(contentsOfFile: imageURL.path) {
      ZStack {
        Image(uiImage: image)
          .resizable()
        Image(uiImage: image)
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.DS.Text.subdued)
          .mask(alignment: .leading) {
            GeometryReader { geometry in
              if viewStore.isPlaying {
                Rectangle().frame(width: geometry.size.width * viewStore.progress)
              } else {
                Rectangle()
              }
            }
          }
      }
    }
  }
}

#if DEBUG
  struct WaveformProgressView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        WaveformProgressView(
          store: Store(
            initialState: WaveformProgress.State(),
            reducer: WaveformProgress()
          )
        )
      }
    }
  }
#endif
