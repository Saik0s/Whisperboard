//
// Created by Igor Tarasenko on 15/01/2023.
//

import DSWaveformImage
import DSWaveformImageViews
import SwiftUI

struct WaveformProgressView: View {
  var audioURL: URL
  var progress = 0.0
  var isPlaying = false

  var configuration = Waveform.Configuration(
    size: .zero,
    backgroundColor: .clear,
    style: .striped(.init(color: .white, width: 3, spacing: 3, lineCap: .round)),
    dampening: Waveform.Dampening(),
    position: .middle,
    scale: DSScreen.scale,
    verticalScalingFactor: 0.95,
    shouldAntialias: true
  )
  var notPlayedConfiguration: Waveform.Configuration {
    configuration
      .with(style: .striped(.init(color: UIColor(Color.Palette.Text.subdued), width: 3, spacing: 3, lineCap: .round)))
  }

  var fileExists: Bool {
    FileManager.default.fileExists(atPath: audioURL.path)
  }

  var body: some View {
    ZStack(alignment: .leading) {
      if fileExists {
        WaveformView(audioURL: audioURL, configuration: notPlayedConfiguration)
        WaveformView(audioURL: audioURL, configuration: configuration)
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
    }
      .frame(maxWidth: .infinity)
      .animation(.linear(duration: 0.5), value: progress)
  }
}
