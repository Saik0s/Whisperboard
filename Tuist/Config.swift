import ProjectDescription

let config = Config(
  compatibleXcodeVersions: .upToNextMajor("15.3.0"),
  swiftVersion: "5.10",
  generationOptions: .options(
    enforceExplicitDependencies: true
  )
)
