import ProjectDescription

/// Project helpers are functions that simplify the way you define your project.
/// Share code to create targets, settings, dependencies,
/// Create your own conventions, e.g: a func that makes sure all shared targets are "static frameworks"
/// See https://docs.tuist.io/guides/helpers/
///

let projectSettings: SettingsDictionary = [
  "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
  "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
  "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
]

let debugSettings: SettingsDictionary = [
  "OTHER_SWIFT_FLAGS": "-D DEBUG $(inherited) -Xfrontend -warn-long-function-bodies=500 -Xfrontend -warn-long-expression-type-checking=500 -Xfrontend -debug-time-function-bodies -Xfrontend -enable-actor-data-race-checks",
  "OTHER_LDFLAGS": "-Xlinker -interposable $(inherited)",
]

let releaseSettings: SettingsDictionary = [
  :
]

public extension Project {
  /// Helper function to create a framework target and an associated unit test target
  static func makeFrameworkTargets(name: String, mainDependencies: [TargetDependency],
                                   testDependencies: [TargetDependency]) -> [Target] {
    let sources = Target(
      name: name,
      platform: .iOS,
      product: .framework,
      bundleId: "me.igortarasenko.\(name)",
      deploymentTarget: .iOS(targetVersion: "16.0", devices: [.iphone, .ipad]),
      infoPlist: .default,
      sources: .paths([.relativeToManifest("Sources/**")]),
      resources: [],
      dependencies: mainDependencies
    )
    let tests = Target(
      name: "\(name)Tests",
      platform: .iOS,
      product: .unitTests,
      bundleId: "me.igortarasenko.\(name)Tests",
      deploymentTarget: .iOS(targetVersion: "16.0", devices: [.iphone, .ipad]),
      infoPlist: .default,
      sources: .paths([.relativeToManifest("Tests/**")]),
      resources: [],
      dependencies: [.target(name: name)] + testDependencies
    )
    return [sources, tests]
  }

  /// Helper function to create a project with a framework target and an associated unit test target
  static func frameworkProject(
    name: String,
    mainDependencies: [TargetDependency] = [],
    testDependencies: [TargetDependency] = [],
    additionalProjectSettings: SettingsDictionary = [:],
    additionalDebugSettings: SettingsDictionary = [:],
    additionalReleaseSettings: SettingsDictionary = [:]
  ) -> Project {
    let projectSettingsMerged = projectSettings.merging(additionalProjectSettings) { _, new in new }
    let debugSettingsMerged = debugSettings.merging(additionalDebugSettings) { _, new in new }
    let releaseSettingsMerged = releaseSettings.merging(additionalReleaseSettings) { _, new in new }
    let frameworkTargets = makeFrameworkTargets(
      name: name,
      mainDependencies: mainDependencies,
      testDependencies: testDependencies
    )
    return Project(
      name: name,
      organizationName: "me.igortarasenko",
      options: .options(
        disableShowEnvironmentVarsInScriptPhases: true,
        textSettings: .textSettings(
          indentWidth: 2,
          tabWidth: 2
        )
      ),
      settings: .settings(
        base: projectSettingsMerged,
        debug: debugSettingsMerged,
        release: releaseSettingsMerged,
        defaultSettings: .recommended
      ),
      targets: frameworkTargets,
      additionalFiles: []
    )
  }
}
