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
  "OTHER_LDFLAGS": "-Xlinker -interposable -Xlinker -undefined -Xlinker dynamic_lookup $(inherited)",
  "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Sources/Common/Bridging.h",
]

let releaseSettings: SettingsDictionary = [
  "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Sources/Common/Bridging.h",
]

func appKitTarget() -> Target {
  Target(
    name: "WhisperBoardKit",
    platform: .iOS,
    product: .staticFramework,
    bundleId: "me.igortarasenko.WhisperboardKit",
    deploymentTarget: .iOS(targetVersion: "16.0", devices: [.iphone, .ipad]),
    infoPlist: .extendingDefault(with: [:]),
    sources: .paths([.relativeToManifest("Sources/**")]),
    resources: [
      "Resources/Assets.xcassets",
      "Resources/ggml-tiny.bin",
    ],
    scripts: [
      .post(
        path: "../ci_scripts/post_build_checks.sh",
        name: "Additional Checks",
        basedOnDependencyAnalysis: false
      ),
    ],
    dependencies: [
      .external(name: "AppDevUtils"),
      .external(name: "Inject"),

      .external(name: "DSWaveformImage"),
      .external(name: "DSWaveformImageViews"),
      .external(name: "DynamicColor"),
      .external(name: "Popovers"),

      .external(name: "AudioKit"),

      .external(name: "ComposableArchitecture"),
      .external(name: "AsyncAlgorithms"),
      .external(name: "DependenciesAdditions"),

      .external(name: "VariableBlurView"),
      .external(name: "SwiftUIIntrospect"),
      .external(name: "BetterCodable"),

      .external(name: "whisper"),
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
    .files(extensions: ["bin", "json"]),
    .assets(),
  ]
)
