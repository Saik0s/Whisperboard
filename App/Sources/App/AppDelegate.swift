import Foundation
import UIKit
import SwiftUI
import ComposableArchitecture
import Dependencies

class AppDelegate: UIResponder, UIApplicationDelegate {
  var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    true
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    @Dependency(\.transcriber) var transcriber: TranscriberClient

    guard transcriber.transcriberState().isTranscribing else { return }

    backgroundTask = application.beginBackgroundTask(withName: "Transcription", expirationHandler: { [weak self] in
      self?.endBackgroundTask()
    })

    Task.detached(priority: .background) { [weak self] in
      for await state in transcriber.transcriberStateStream() {
        if !state.isTranscribing {
          break
        }
      }
      await self?.endBackgroundTask()
    }
  }

  func endBackgroundTask() {
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }
}
