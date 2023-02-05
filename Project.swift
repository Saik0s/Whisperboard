import Foundation
import ProjectDescription

let projectSettings: SettingsDictionary = [
  "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
  "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
  "CODE_SIGN_STYLE": "Automatic",
  "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
  "MARKETING_VERSION": "1.3.0",
]

let debugSettings: SettingsDictionary = [
  "OTHER_SWIFT_FLAGS": "-D DEBUG $(inherited) -Xfrontend -warn-long-function-bodies=500 -Xfrontend -warn-long-expression-type-checking=500 -Xfrontend -debug-time-function-bodies -Xfrontend -enable-actor-data-race-checks",
  "OTHER_LDFLAGS": "-Xlinker -interposable $(inherited)",
]

func appTarget(isHot: Bool = false) -> Target {
  Target(
    name: "WhisperBoard" + (isHot ? "Hot" : ""),
    platform: .iOS,
    product: .app,
    bundleId: "me.igortarasenko.Whisperboard" + (isHot ? ".hot" : ""),
    deploymentTarget: .iOS(targetVersion: "16.0", devices: .iphone),
    infoPlist: .extendingDefault(with: [
      "CFBundleShortVersionString": "$(MARKETING_VERSION)",
      "CFBundleURLTypes": [
        [
          "CFBundleTypeRole": "Editor",
          "CFBundleURLName": .string("WhisperBoard" + (isHot ? "Hot" : "")),
          "CFBundleURLSchemes": [
            .string("whisperboard" + (isHot ? "-hot" : "")),
          ],
        ],
      ],
      "UIApplicationSceneManifest": [
        "UIApplicationSupportsMultipleScenes": false,
        "UISceneConfigurations": [
        ],
      ],
      "ITSAppUsesNonExemptEncryption": false,
      "UILaunchScreen": [
        "UILaunchScreen": [:],
      ],
      "NSMicrophoneUsageDescription": "WhisperBoard uses the microphone to record voice and later transcribe it.",
      "UIUserInterfaceStyle": "Dark",
    ]),
    sources: .paths([.relativeToManifest("App/Sources/**")]),
    resources: [
      "App/Resources/**",
    ],
    dependencies: [
      .target(name: "WhisperBoardKeyboard" + (isHot ? "Hot" : "")),
      .external(name: "AppDevUtils"),
      .external(name: "Inject"),
      .external(name: "OpenAI"),
      .external(name: "DSWaveformImage"),
      .external(name: "DSWaveformImageViews"),
      .package(product: "whisper"),
    ] + (isHot ? [.package(product: "HotReloading")] : [])
  )
}

func keyboardTarget(isHot: Bool = false) -> Target {
  Target(
    name: "WhisperBoardKeyboard" + (isHot ? "Hot" : ""),
    platform: .iOS,
    product: .appExtension,
    bundleId: "me.igortarasenko.Whisperboard\(isHot ? ".hot" : "").Keyboard",
    infoPlist: .extendingDefault(with: [
      "CFBundleDisplayName": "WhisperBoard\(isHot ? " Hot" : "") Keyboard",
      "CFBundleShortVersionString": "$(MARKETING_VERSION)",
      "NSExtension": [
        "NSExtensionAttributes": [
          "PrimaryLanguage": "en-US",
          "PrefersRightToLeft": false,
          "IsASCIICapable": false,
          "RequestsOpenAccess": false,
        ],
        "NSExtensionPointIdentifier": "com.apple.keyboard-service",
        "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).KeyboardViewController",
      ],
    ]),
    sources: .paths([.relativeToManifest("Keyboard/Sources/**")]),
    resources: [
      "Keyboard/Resources/**",
    ],
    dependencies: [
      .external(name: "KeyboardKit"),
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
  packages: [
    .package(url: "https://github.com/ggerganov/whisper.spm", .branch("master")),
    .package(url: "https://github.com/johnno1962/HotReloading", .branch("main")),
  ],
  settings: .settings(
    base: projectSettings,
    debug: debugSettings,
    release: [:],
    defaultSettings: .recommended
  ),
  targets: [
    appTarget(),
    appTarget(isHot: true),
    keyboardTarget(),
    keyboardTarget(isHot: true),
  ],
  resourceSynthesizers: [
    .files(extensions: ["bin"]),
  ]
)
