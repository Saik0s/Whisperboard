import ProjectDescription

let packages: [Package] = [
  .package(url: "https://github.com/Saik0s/AppDevUtils.git", .upToNextMajor(from: "0.2.0")),
  .package(url: "https://github.com/krzysztofzablocki/Inject.git", .branch("main")),
  .package(url: "https://github.com/dmrschmidt/DSWaveformImage.git", .upToNextMajor(from: "11.0.0")),
  // .package(url: "https://github.com/jasudev/LottieUI.git", .branch("main")),
  .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
  .package(url: "https://github.com/ggerganov/whisper.spm", from: "1.2.1"),
]

let dependencies = Dependencies(
  swiftPackageManager: .init(packages),
  platforms: [.iOS]
)
