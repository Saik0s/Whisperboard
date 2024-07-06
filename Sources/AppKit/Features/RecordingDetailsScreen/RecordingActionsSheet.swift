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

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .toggleDisplayMode:
        state.displayMode = state.displayMode == .text ? .timeline : .text
        return .none
      case .copyText, .delete, .exportSRT, .exportText, .exportVTT, .restartTranscription, .shareAudio:
        // Implement these actions in the parent reducer
        return .none
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
      .padding()
      .background(Color.DS.Background.secondary)
      .cornerRadius(16)
      .padding()
    }
  }

  private var displayModeToggle: some View {
    Toggle(isOn: .init { store.displayMode == .timeline } set: { _ in
      store.send(.toggleDisplayMode)
    }) {
      Text("Timeline View")
    }
  }

  private var exportOptions: some View {
    VStack(alignment: .leading, spacing: .grid(2)) {
      Text("Export")
        .font(.headline)

      Button(action: { store.send(.exportText) }) {
        Label("Export Text", systemImage: "doc.text")
      }

      Button(action: { store.send(.exportVTT) }) {
        Label("Export VTT", systemImage: "doc.plaintext")
      }

      Button(action: { store.send(.exportSRT) }) {
        Label("Export SRT", systemImage: "doc.plaintext")
      }

      Button(action: { store.send(.shareAudio) }) {
        Label("Share Audio", systemImage: "square.and.arrow.up")
      }

      Button(action: { store.send(.copyText) }) {
        Label("Copy Text", systemImage: "doc.on.doc")
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
        Button(action: { store.send(.restartTranscription) }) {
          Label("Restart Transcription", systemImage: "arrow.clockwise")
        }
      }
    }
  }
}
