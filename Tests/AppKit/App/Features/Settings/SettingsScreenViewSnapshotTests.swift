import ComposableArchitecture
import Dependencies
import SnapshotTesting
import SwiftUI
@testable import WhisperBoardKit
import XCTest

class SettingsScreenViewSnapshotTests: XCTestCase {
  override class func setUp() {
    super.setUp()

    SnapshotTesting.isRecording = false
  }

  func testSettingsScreenView() {
    let store: StoreOf<SettingsScreen> = Store(initialState: SettingsScreen.State()) {
      SettingsScreen()
    } withDependencies: {
      $0.build.version = { "1.0.0" }
      $0.build.buildNumber = { "100" }
      $0[StorageClient.self].freeSpace = { @Sendable in 1_000_000_000 }
      $0[StorageClient.self].takenSpace = { @Sendable in 500_000_000 }
      $0.subscriptionClient.checkIfSubscribed = { true }
    }

    let view = SettingsScreenView(store: store)
      .background(Color.DS.Background.primary)
      .environment(\.colorScheme, .dark)
      .environment(TabBarViewModel())

    assertSnapshots(
      matching: view,
      as: [
        .image(layout: .device(config: .iPhone13ProMax), traits: .iPhone13ProMax(.portrait)),
        .image(layout: .device(config: .iPhoneSe), traits: .iPhoneSe(.portrait)),
        .image(layout: .device(config: .iPadPro12_9), traits: .iPadPro12_9),
        .image(layout: .device(config: .iPadMini), traits: .iPadMini),
      ]
    )
  }
}
