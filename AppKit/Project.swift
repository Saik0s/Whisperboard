import Foundation
import ProjectDescription

let projectSettings: SettingsDictionary = [
  "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
  "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
  "CODE_SIGN_STYLE": "Automatic",
  "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
  "ENABLE_BITCODE": "NO",
]

let debugSettings: SettingsDictionary = [
  "OTHER_SWIFT_FLAGS": "-D DEBUG $(inherited) -Xfrontend -warn-long-function-bodies=500 -Xfrontend -warn-long-expression-type-checking=500 -Xfrontend -debug-time-function-bodies -Xfrontend -enable-actor-data-race-checks",
  "OTHER_LDFLAGS": "-Xlinker -interposable $(inherited)",
  "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Support/Bridging.h",
]

let releaseSettings: SettingsDictionary = [
  "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Support/Bridging.h",
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
      "Resources/**",
    ],
    dependencies: [
      .sdk(name: "c++", type: .library, status: .required),
      .sdk(name: "CloudKit", type: .framework, status: .optional),
      .sdk(name: "StoreKit", type: .framework, status: .optional),
      .external(name: "AsyncAlgorithms"),
      .external(name: "AudioKit"),
      .external(name: "ComposableArchitecture"),
      .external(name: "DSWaveformImage"),
      .external(name: "DSWaveformImageViews"),
      .external(name: "DependenciesAdditions"),
      .external(name: "DynamicColor"),
      .external(name: "Inject"),
      .external(name: "KeychainAccess"),
      .external(name: "Popovers"),
      .external(name: "RevenueCat"),
      .external(name: "SwiftUIIntrospect"),
      .external(name: "VariableBlurView"),
      .external(name: "whisper"),
      .external(name: "Lottie"),
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
      .external(name: "SnapshotTesting"),
    ]
  )
}

let project = Project(
  name: "WhisperBoardKit",

  options: .options(
    automaticSchemesOptions: .disabled,
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

  schemes: [
    Scheme(
      name: "WhisperBoardKit",
      shared: true,
      buildAction: .buildAction(targets: ["WhisperBoardKit"]),
      testAction: .targets(["WhisperBoardKitTests"])
    ),
  ],

  resourceSynthesizers: [
    .files(extensions: ["bin"]),
    .assets(),
    .fonts(),
    .strings(),
    .custom(
      name: "Lottie",
      parser: .json,
      extensions: ["lottie"]
    ),
  ]
)
