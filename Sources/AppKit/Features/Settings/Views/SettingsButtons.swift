import Common
import Inject
import SwiftUI

// MARK: - SettingsIconView

struct SettingsIconView: View {
  let icon: Image
  let iconBGColor: Color

  var body: some View {
    icon
      .font(.footnote)
      .foregroundColor(.DS.Text.base)
      .frame(width: 28, height: 28)
      .background(iconBGColor)
      .cornerRadius(6)
  }

  static func system(name systemName: String, background: Color = .DS.Background.accent) -> Self {
    Self(icon: Image(systemName: systemName), iconBGColor: background)
  }
}

// MARK: - SettingsButton

struct SettingsButton: View {
  enum TrailingIcon {
    case openOutside, chevron
  }

  let icon: SettingsIconView
  let title: String
  var trailingText: String?
  var indicator: TrailingIcon?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: .grid(3)) {
        icon

        Text(title)
          .textStyle(.label)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let trailingText {
          Text(trailingText)
            .textStyle(.sublabel)
        }

        if let indicator {
          switch indicator {
          case .openOutside:
            Image(systemName: "arrow.up.forward")
              .foregroundColor(.DS.Text.subdued)

          case .chevron:
            Image(systemName: "chevron.right")
              .foregroundColor(.DS.Text.subdued)
          }
        }
      }
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
    }
    .buttonStyle(SettingsButtonStyle())
  }
}

// MARK: - SettingsSheetButton

struct SettingsSheetButton<Content: View>: View {
  let icon: SettingsIconView
  let title: String
  var trailingText: String? = nil
  var content: Content

  @State var isActive = false

  init(icon: SettingsIconView, title: String, trailingText: String? = nil, @ViewBuilder content: () -> Content) {
    self.icon = icon
    self.title = title
    self.trailingText = trailingText
    self.content = content()
  }

  var body: some View {
    Button(action: { isActive.toggle() }) {
      HStack(spacing: .grid(3)) {
        icon

        Text(title)
          .textStyle(.label)
          .fixedSize(horizontal: false, vertical: true)

        Spacer()

        if let trailingText {
          Text(trailingText)
            .textStyle(.sublabel)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }

        Image(systemName: "chevron.forward")
          .foregroundColor(.DS.Text.subdued)
      }
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
    }
    .buttonStyle(SettingsButtonStyle())
    .sheet(isPresented: $isActive) {
      content
    }
  }
}

// MARK: - SettingsInlinePickerButton

struct SettingsInlinePickerButton: View {
  let icon: SettingsIconView
  let title: String
  var choices: [String]
  @Binding var selectedIndex: Int

  var body: some View {
    HStack(spacing: .grid(3)) {
      icon

      Text(title)
        .textStyle(.label)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)

      Picker("", selection: $selectedIndex) {
        ForEach(Array(zip(choices.indices, choices)), id: \.1) { index, choice in
          Text(choice)
            .textStyle(.label)
            .tag(index)
        }
      }
      .pickerStyle(.menu)
      .tint(.DS.Text.subdued)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

// MARK: - SettingsToggleButton

struct SettingsToggleButton: View {
  let icon: SettingsIconView
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: .grid(3)) {
      icon

      Text(title)
        .textStyle(.label)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)

      Toggle("", isOn: $isOn)
        .labelsHidden()
    }
    .onTapGesture {
      isOn.toggle()
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

// MARK: - SettingsButtonStyle

struct SettingsButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background {
        if configuration.isPressed {
          Color.primary.opacity(0.1)
        }
      }
  }
}
