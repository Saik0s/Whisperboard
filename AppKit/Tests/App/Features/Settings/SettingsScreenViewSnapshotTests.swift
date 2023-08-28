import ComposableArchitecture
import Dependencies
import SnapshotTesting
import SwiftUI
@testable import WhisperBoardKit
import XCTest

@MainActor
class SettingsScreenViewSnapshotTests: XCTestCase {
  override class func setUp() {
    super.setUp()

    SnapshotTesting.isRecording = false
  }

  func testSettingsScreenView() {
    let store: StoreOf<SettingsScreen> = Store(initialState: .init()) { SettingsScreen() } withDependencies: {
      $0.modelDownload = .previewValue
    }

    let view = SettingsScreenView(store: store)
      .background(Color.DS.Background.primary)
      .environment(\.colorScheme, .dark)
      .environmentObject(TabBarViewModel())

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
