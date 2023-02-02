import AppDevUtils
import DSWaveformImage
import DSWaveformImageViews
import SwiftUI

import AppDevUtils
import Inject
import SwiftUI
import ComposableArchitecture

public struct WaveformProgress: ReducerProtocol {
  public struct State: Equatable {
    var fileName = ""
    var progress = 0.0
    var isPlaying = false

)
    var notPlayedConfiguration: Waveform.Configuration {
      configuration
        .with(style: .striped(.init(color: UIColor(Color.DS.Text.subdued), width: 2, spacing: 4, lineCap: .round)))
    }

    var fileExists: Bool {
      FileManager.default.fileExists(atPath: audioURL.path)
    }
  }

  public enum Action: Equatable {
    case task
  }

  @Dependency(\.storage) var storage: StorageClient
  let waveImageDrawer = WaveformImageDrawer()
  let configuration = Waveform.Configuration(
    size: .zero,
    backgroundColor: .clear,
    style: .striped(.init(color: .white, width: 2, spacing: 4, lineCap: .round)),
    dampening: .init(percentage: 0.125, sides: .both),
    position: .middle,
    scale: DSScreen.scale,
    verticalScalingFactor: 0.95,
    shouldAntialias: true
  )

  public var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        let waveImageURL = storage.waveFileURLWithName(state.fileName + ".png")
        let audioURL = storage.audioFileURLWithName(state.fileName)
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
          return .none
        }

        return .none

        // return .task {
        //   if let image = UIImage(contentsOfFile: )
        //   let image = await waveImageDrawer.waveformImage(fromAudioAt: audioURL, with: configuration)
        // }
      }
    }
  }
}

public struct WaveformProgressView: View {
  @ObserveInjection var inject

  let store: StoreOf<WaveformProgress>

  public init(store: StoreOf<WaveformProgress>) {
    self.store = store
  }

  public var body: some View {
    ZStack {
      Image("")
      Image("")
          .mask(alignment: .leading) {
            GeometryReader { geometry in
              if isPlaying {
                Rectangle().frame(width: geometry.size.width * progress)
              } else {
                Rectangle()
              }
            }
          }
    }
      .frame(height: 50)
      .frame(maxWidth: .infinity)
      .animation(.linear(duration: 0.1), value: progress)
      .enableInjection()
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
