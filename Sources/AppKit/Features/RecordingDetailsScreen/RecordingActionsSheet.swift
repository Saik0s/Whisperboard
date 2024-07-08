import Common
import ComposableArchitecture
import Inject
import SwiftUI
import WhisperKit

// MARK: - RecordingActionsSheet

@Reducer
struct RecordingActionsSheet {
  @ObservableState
  struct State: Equatable {
    var displayMode: RecordingDetails.DisplayMode
    var isTranscribing: Bool
    var transcription: Transcription?
    var audioFileURL: URL
  }

  enum Action: Equatable {
    case toggleDisplayMode
    case exportText
    case exportVTT
    case exportSRT
    case shareAudio
    case copyText
    case delete
    case restartTranscription
  }

  @Dependency(\.hapticEngine) var hapticEngine

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .toggleDisplayMode:
        state.displayMode = state.displayMode == .text ? .timeline : .text
        return .run { _ in
          await hapticEngine.feedback(.medium)
        }

      case .copyText, .delete, .exportSRT, .exportText, .exportVTT, .restartTranscription, .shareAudio:
        return .run { _ in
          await hapticEngine.feedback(.medium)
        }
      }
    }
  }
}

// MARK: - RecordingActionsSheetView

struct RecordingActionsSheetView: View {
  @Perception.Bindable var store: StoreOf<RecordingActionsSheet>

  @ObserveInjection var inject

  var body: some View {
    WithPerceptionTracking {
      Form {
        displayModeToggle
        exportOptions
        otherActions
      }
      .enableInjection()
    }
  }

  private var displayModeToggle: some View {
    Toggle(isOn: .init { store.displayMode == .timeline } set: { _ in
      store.send(.toggleDisplayMode)
    }) {
      Text("Timeline View")
    }
    .toggleStyle(SwitchToggleStyle(tint: .DS.Text.accent))
  }

  private var exportOptions: some View {
    Section {
      ShareLink(item: store.transcription?.text ?? "") {
        Label("Share Text", systemImage: "doc.text")
          .foregroundColor(.DS.Text.base)
      }
      shareLink(title: "Export VTT", systemImage: "doc.plaintext", content: generateVTTContent())
      shareLink(title: "Export SRT", systemImage: "doc.plaintext", content: generateSRTContent())
      shareLink(title: "Share Audio", systemImage: "square.and.arrow.up", content: store.audioFileURL)
      actionButton(title: "Copy Text", systemImage: "doc.on.doc", action: .copyText)
    }
  }

  private var otherActions: some View {
    VStack(alignment: .leading, spacing: .grid(2)) {
      Button(action: { store.send(.delete) }) {
        Label("Delete", systemImage: "trash")
          .foregroundColor(.red)
      }

      if store.isTranscribing {
        actionButton(title: "Restart Transcription", systemImage: "arrow.clockwise", action: .restartTranscription)
      }
    }
  }

  private func actionButton(title: String, systemImage: String, action: RecordingActionsSheet.Action) -> some View {
    Button(action: { store.send(action) }) {
      Label(title, systemImage: systemImage)
        .foregroundColor(.DS.Text.base)
    }
  }

  @ViewBuilder
  private func shareLink(title: String, systemImage: String, content: URL?) -> some View {
    if let content {
      ShareLink(item: content) {
        Label(title, systemImage: systemImage)
          .foregroundColor(.DS.Text.base)
      }
    } else {
      Label(title, systemImage: systemImage)
        .foregroundColor(.DS.Text.subdued)
    }
  }

  private func generateVTTContent() -> URL? {
    guard let transcription = store.transcription else { return nil }

    var vttContent = "WEBVTT\n\n"
    for segment in transcription.segments {
      vttContent += formatTiming(start: Float(segment.startTimeMS) / 1000, end: Float(segment.endTimeMS) / 1000, text: segment.text)
    }

    let fileName = store.audioFileURL.deletingPathExtension().lastPathComponent
    return saveToFile(content: vttContent, fileName: fileName, fileExtension: "vtt")
  }

  private func generateSRTContent() -> URL? {
    guard let transcription = store.transcription else { return nil }

    var srtContent = ""
    for (index, segment) in transcription.segments.enumerated() {
      srtContent += formatSegment(index: index + 1, start: Float(segment.startTimeMS) / 1000, end: Float(segment.endTimeMS) / 1000, text: segment.text)
    }

    let fileName = store.audioFileURL.deletingPathExtension().lastPathComponent
    return saveToFile(content: srtContent, fileName: fileName, fileExtension: "srt")
  }

  private func saveToFile(content: String, fileName: String, fileExtension: String) -> URL? {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("\(fileName).\(fileExtension)")

    do {
      try content.write(to: fileURL, atomically: true, encoding: .utf8)
      return fileURL
    } catch {
      logs.error("Error saving file: \(error)")
      return nil
    }
  }

  private func formatTime(seconds: Float, alwaysIncludeHours: Bool, decimalMarker: String) -> String {
    let hrs = Int(seconds / 3600)
    let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
    let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
    let msec = Int((seconds - Float(Int(seconds))) * 1000)

    if alwaysIncludeHours || hrs > 0 {
      return String(format: "%02d:%02d:%02d\(decimalMarker)%03d", hrs, mins, secs, msec)
    } else {
      return String(format: "%02d:%02d\(decimalMarker)%03d", mins, secs, msec)
    }
  }

  private func formatSegment(index: Int, start: Float, end: Float, text: String) -> String {
    let startFormatted = formatTime(seconds: start, alwaysIncludeHours: true, decimalMarker: ",")
    let endFormatted = formatTime(seconds: end, alwaysIncludeHours: true, decimalMarker: ",")
    return "\(index)\n\(startFormatted) --> \(endFormatted)\n\(text)\n\n"
  }

  private func formatTiming(start: Float, end: Float, text: String) -> String {
    let startFormatted = formatTime(seconds: start, alwaysIncludeHours: false, decimalMarker: ".")
    let endFormatted = formatTime(seconds: end, alwaysIncludeHours: false, decimalMarker: ".")
    return "\(startFormatted) --> \(endFormatted)\n\(text)\n\n"
  }
}
