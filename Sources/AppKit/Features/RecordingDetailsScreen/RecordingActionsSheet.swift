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
    @Shared var displayMode: RecordingDetails.DisplayMode
    @SharedReader var isTranscribing: Bool
    @SharedReader var transcription: Transcription?
    @SharedReader var audioFileURL: URL
    var sharingContent: SharingContent?
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case shareAudio
    case shareText
    case shareVTT
    case shareSRT
    case copyText
    case delete
    case restartTranscription
  }

  struct SharingContent: Identifiable, Equatable {
    enum ContentType: Equatable {
      case audio, text, vtt, srt
    }

    let id: UUID = .init()
    let value: Any
    let type: ContentType

    static func == (lhs: SharingContent, rhs: SharingContent) -> Bool {
      lhs.id == rhs.id && lhs.type == rhs.type
    }
  }

  @Dependency(\.hapticEngine) var hapticEngine

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .shareAudio:
        state.sharingContent = SharingContent(value: state.audioFileURL, type: .audio)
        return .run { _ in
          await hapticEngine.feedback(.medium)
        }

      case .shareText:
        return .run { [transcription = state.transcription] send in
          await hapticEngine.feedback(.medium)
          guard let text = transcription?.text, !text.isEmpty else { return }
          await send(.set(\.sharingContent, SharingContent(value: text, type: .text)))
        }

      case .shareVTT:
        return .run { [transcription = state.transcription, audioFileURL = state.audioFileURL] send in
          await hapticEngine.feedback(.medium)
          guard let transcription, !transcription.text.isEmpty else { return }
          if let vttURL = await generateVTTContent(transcription: transcription, audioFileURL: audioFileURL) {
            await send(.set(\.sharingContent, SharingContent(value: vttURL, type: .vtt)))
          }
        }

      case .shareSRT:
        return .run { [transcription = state.transcription, audioFileURL = state.audioFileURL] send in
          await hapticEngine.feedback(.medium)
          guard let transcription, !transcription.text.isEmpty else { return }
          if let srtURL = await generateSRTContent(transcription: transcription, audioFileURL: audioFileURL) {
            await send(.set(\.sharingContent, SharingContent(value: srtURL, type: .srt)))
          }
        }

      case .copyText:
        return .run { [text = state.transcription?.text] _ in
          await hapticEngine.feedback(.medium)
          UIPasteboard.general.string = text
        }

      case .delete, .restartTranscription:
        return .run { _ in
          await hapticEngine.feedback(.medium)
        }
      }
    }
  }

  private func generateVTTContent(transcription: Transcription, audioFileURL: URL) async -> URL? {
    var vttContent = "WEBVTT\n\n"
    for segment in transcription.segments {
      vttContent += formatTiming(start: Float(segment.startTimeMS) / 1000, end: Float(segment.endTimeMS) / 1000, text: segment.text)
    }

    let fileName = audioFileURL.deletingPathExtension().lastPathComponent
    return await saveToFile(content: vttContent, fileName: fileName, fileExtension: "vtt")
  }

  private func generateSRTContent(transcription: Transcription, audioFileURL: URL) async -> URL? {
    var srtContent = ""
    for (index, segment) in transcription.segments.enumerated() {
      srtContent += formatSegment(
        index: index + 1,
        start: Float(segment.startTimeMS) / 1000,
        end: Float(segment.endTimeMS) / 1000,
        text: segment.text
      )
    }

    let fileName = audioFileURL.deletingPathExtension().lastPathComponent
    return await saveToFile(content: srtContent, fileName: fileName, fileExtension: "srt")
  }

  private func saveToFile(content: String, fileName: String, fileExtension: String) async -> URL? {
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
      .sheet(item: $store.sharingContent) { content in
        ActivityViewController(activityItems: [content.value])
      }
      .enableInjection()
    }
  }

  private var displayModeToggle: some View {
    Picker("Display Mode", selection: $store.displayMode) {
      Label("Text", systemImage: "text.alignleft")
        .tag(RecordingDetails.DisplayMode.text)

      Label("Timeline", systemImage: "timeline.selection")
        .tag(RecordingDetails.DisplayMode.timeline)
    }
    .pickerStyle(.segmented)
  }

  private var exportOptions: some View {
    Section {
      actionButton(title: "Share Audio", systemImage: "square.and.arrow.up", action: .shareAudio)
      actionButton(title: "Copy Text", systemImage: "doc.on.doc", action: .copyText, isDisabled: store.transcription?.text.isEmpty ?? true)
      actionButton(
        title: "Export Text",
        systemImage: "square.and.arrow.up",
        action: .shareText,
        isDisabled: store.transcription?.text.isEmpty ?? true
      )
      actionButton(title: "Export VTT", systemImage: "square.and.arrow.up", action: .shareVTT, isDisabled: store.transcription?.text.isEmpty ?? true)
      actionButton(title: "Export SRT", systemImage: "square.and.arrow.up", action: .shareSRT, isDisabled: store.transcription?.text.isEmpty ?? true)
    }
  }

  @ViewBuilder private var otherActions: some View {
    actionButton(title: "Restart Transcription", systemImage: "arrow.clockwise", action: .restartTranscription, isDisabled: store.isTranscribing)

    Button(action: { store.send(.delete) }) {
      Label("Delete", systemImage: "trash")
        .foregroundColor(.red)
    }
    .buttonStyle(TapEffectButtonStyle())
  }

  private func actionButton(title: String, systemImage: String, action: RecordingActionsSheet.Action, isDisabled: Bool = false) -> some View {
    Button(action: { store.send(action) }) {
      Label(title, systemImage: systemImage)
        .foregroundColor(isDisabled ? .gray : .DS.Text.base)
    }
    .disabled(isDisabled)
    .buttonStyle(TapEffectButtonStyle())
  }
}

// MARK: - ActivityViewController

struct ActivityViewController: UIViewControllerRepresentable {
  let activityItems: [Any]
  let applicationActivities: [UIActivity]? = nil

  func makeUIViewController(context _: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
    let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    activityViewController.modalPresentationStyle = .custom
    let detents: [UISheetPresentationController.Detent] = [.medium()]
    activityViewController.sheetPresentationController?.detents = detents
    return activityViewController
  }

  func updateUIViewController(_: UIActivityViewController, context _: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

// MARK: - TapEffectButtonStyle

private struct TapEffectButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .opacity(configuration.isPressed ? 0.7 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
  }
}
