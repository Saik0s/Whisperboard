//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Igor Tarasenko on 24/12/2022.
//

import SwiftUI
import UIKit
import KeyboardKit

struct KeyboardView: View {
  @EnvironmentObject
  private var keyboardContext: KeyboardContext

  private var rowHeight: CGFloat { KeyboardLayoutConfiguration.standard(for: keyboardContext).rowHeight }

  var urlOpener: URLOpener

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button {
          urlOpener.open(urlString: "whisperboard://")
        } label: {
          Image("whisper_icon")
            .resizable()
            .foregroundColor(.white)
            .padding(rowHeight * 0.15)
            .background {
              Circle().fill(Color(UIColor.systemBlue))
            }
            .padding(4)
            .frame(width: rowHeight, height: rowHeight)
        }

        Spacer()
      }
        .frame(height: rowHeight)

      SystemKeyboard()
    }
  }
}

class KeyboardViewController: KeyboardInputViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
  }

  override func viewWillSetupKeyboard() {
    super.viewWillSetupKeyboard()
    setup(with: KeyboardView(urlOpener: URLOpener(responder: self)))
  }
}
