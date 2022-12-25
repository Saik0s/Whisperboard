//
//  WhisperboardApp.swift
//  Whisperboard
//
//  Created by Igor Tarasenko on 24/12/2022.
//

import SwiftUI
import ComposableArchitecture

@main
struct WhisperboardApp: App {
    var body: some Scene {
        WindowGroup {
            WhispersView(
              store: Store(
                initialState: Whispers.State(),
                reducer: Whispers()._printChanges()
              )
            )
        }
    }
}
