// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/Saik0s/AppDevUtils.git", branch: "main"),
        .package(url: "https://github.com/Saik0s/OpenAI.git", branch: "main"),
        .package(url: "https://github.com/krzysztofzablocki/Inject.git", branch: "main"),
        .package(url: "https://github.com/KeyboardKit/KeyboardKit.git", from: "6.9.4"),
        .package(url: "https://github.com/dmrschmidt/DSWaveformImage.git", from: "11.0.0"),
        .package(url: "https://github.com/jasudev/LottieUI.git", branch: "main"),
    ]
)