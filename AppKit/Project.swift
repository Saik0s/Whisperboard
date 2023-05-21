import Foundation
import ProjectDescription

let projectSettings: SettingsDictionary = [
  "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
  "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
  "CODE_SIGN_STYLE": "Automatic",
  "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
  "OTHER_LDFLAGS": "-lc++ $(inherited)",
]

let debugSettings: SettingsDictionary = [
  "OTHER_SWIFT_FLAGS": "-D DEBUG $(inherited) -Xfrontend -warn-long-function-bodies=500 -Xfrontend -warn-long-expression-type-checking=500 -Xfrontend -debug-time-function-bodies -Xfrontend -enable-actor-data-race-checks",
  "OTHER_LDFLAGS": "-Xlinker -interposable $(inherited)",
  "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Sources/Common/Bridging.h",
]

let releaseSettings: SettingsDictionary = [
  "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Sources/Common/Bridging.h",
]

func appKitTarget() -> Target {
  Target(
    name: "WhisperBoardKit",
    platform: .iOS,
    product: .framework,
    bundleId: "me.igortarasenko.WhisperboardKit",
    deploymentTarget: .iOS(targetVersion: "16.0", devices: [.iphone, .ipad]),
    infoPlist: .extendingDefault(with: [:]),
    sources: .paths([.relativeToManifest("Sources/**")]),
    resources: [
      "Resources/Assets.xcassets",
      "Resources/ggml-tiny.bin",
    ],
    dependencies: [
      .external(name: "AppDevUtils"),
      .external(name: "Inject"),

      .external(name: "DSWaveformImage"),
      .external(name: "DSWaveformImageViews"),
      .external(name: "DynamicColor"),
      .external(name: "Setting"),
      .external(name: "Popovers"),
      // .external(name: "Lottie"),
      // .external(name: "LottieUI"),

      .external(name: "AudioKit"),

      .external(name: "ComposableArchitecture"),
      // .external(name: "ComposablePresentation"),
      .external(name: "AsyncAlgorithms"),
      .external(name: "DependenciesAdditions"),
      .external(name: "Supabase"),

      .project(target: "RecognitionKit", path: "../RecognitionKit"),
    ]
  )
}

func appKitTestTarget() -> Target {
  Target(
    name: "WhisperBoardKitTests",
    platform: .iOS,
    product: .unitTests,
    bundleId: "me.igortarasenko.WhisperboardKitTests",
    infoPlist: .default,
    sources: .paths([.relativeToManifest("Tests/**")]),
    dependencies: [
      .target(name: "WhisperBoardKit"),
    ]
  )
}

let project = Project(
  name: "WhisperBoard",
  options: .options(
    disableShowEnvironmentVarsInScriptPhases: true,
    textSettings: .textSettings(
      indentWidth: 2,
      tabWidth: 2
    )
  ),
  settings: .settings(
    base: projectSettings,
    debug: debugSettings,
    release: releaseSettings,
    defaultSettings: .recommended
  ),
  targets: [
    appKitTarget(),
    appKitTestTarget(),
  ],
  resourceSynthesizers: [
    .files(extensions: ["bin", "json"]),
    .assets(),
  ]
)
