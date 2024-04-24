import ProjectDescription

let workspace = Workspace(
  name: "WhisperBoard",
  projects: ["App", "AppKit"],
  generationOptions: .options(
    lastXcodeUpgradeCheck: Version(15, 3, 0)
  )
)
