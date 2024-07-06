import ComposableArchitecture
import SwiftUI
import Common

// MARK: - RecordingActionsSheet

@Reducer
struct RecordingActionsSheet {
  @ObservableState
  struct State: Equatable {
    var displayMode: RecordingDetails.DisplayMode
    var isTranscribing: Bool
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
          await hapticEngine.feedback(.selection)
        }
      case .copyText, .delete, .exportSRT, .exportText, .exportVTT, .restartTranscription, .shareAudio:
        return .run { _ in
          await hapticEngine.feedback(.selection)
        }
      }
    }
  }
}

// MARK: - RecordingActionsSheetView

struct RecordingActionsSheetView: View {
  let store: StoreOf<RecordingActionsSheet>

  var body: some View {
    WithPerceptionTracking {
      VStack(spacing: .grid(3)) {
        displayModeToggle
        Divider()
        exportOptions
        Divider()
        otherActions
      }
      .padding(.horizontal, .grid(4))
      .padding(.vertical, .grid(3))
      .background(Color.DS.Background.secondary)
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
    VStack(alignment: .leading, spacing: .grid(2)) {
      Text("Export")
        .font(.headline)
        .foregroundColor(.DS.Text.base)

      Group {
        actionButton(title: "Export Text", systemImage: "doc.text", action: .exportText)
        actionButton(title: "Export VTT", systemImage: "doc.plaintext", action: .exportVTT)
        actionButton(title: "Export SRT", systemImage: "doc.plaintext", action: .exportSRT)
        actionButton(title: "Share Audio", systemImage: "square.and.arrow.up", action: .shareAudio)
        actionButton(title: "Copy Text", systemImage: "doc.on.doc", action: .copyText)
      }
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
}
