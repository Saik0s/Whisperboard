import ProjectDescription

let workspace = Workspace(
  name: "WhisperBoard",
  projects: ["."],
  generationOptions: .options(
    lastXcodeUpgradeCheck: Version(15, 3, 0)
  )
)
