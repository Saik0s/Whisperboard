//
//  ContentView.swift
//  Whisperboard
//
//  Created by Igor Tarasenko on 24/12/2022.
//

import SwiftUI

struct ContentView: View {
  @StateObject var appModel = AppModel()

  var body: some View {
    VStack {
      VStack {
        if appModel.isLoadingModel || appModel.isTranscribing {
          ActivityIndicator()
        }
        Button {
          Task {
            await appModel.toggleRecord()
          }
        } label: {
          Text(appModel.isRecording ? "Stop recording" : "Start recording")
        }
          .buttonStyle(MyButtonStyle())
          .disabled(!appModel.canTranscribe)

        VStack {
          ForEach(appModel.recordings) { recording in
            VStack(alignment: .leading) {
              Text(recording.fileURL.lastPathComponent)
                .font(.system(.footnote))
              Text(recording.text)
                .frame(minHeight: 20)
                .padding()
                .background {
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(UIColor.systemGray2), lineWidth: 1)
                }

              HStack {
                Button {
                  UIPasteboard.general.string = recording.text
                } label: {
                  Text("Copy")
                }
                  .buttonStyle(MyButtonStyle())

                Button {
                  let text = recording.text
                  let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)

                  UIApplication.shared.windows.first?.rootViewController?.present(activityController, animated: true, completion: nil)
                } label: {
                  Text("Share")
                }
                  .buttonStyle(MyButtonStyle())
              }
            }
              .frame(maxWidth: .infinity, alignment: .leading)
              .multilineTextAlignment(.leading)
              .padding()

            if recording != appModel.recordings.last {
              Divider()
            }
          }
        }
          .padding()
          .background(Color(UIColor.systemGray5))
          .cornerRadius(8)
          .padding()
      }
    }
      .padding()
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
