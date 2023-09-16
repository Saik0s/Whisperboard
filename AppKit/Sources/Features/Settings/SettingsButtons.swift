import Inject
import SwiftUI

// MARK: - SettingsButton

struct SettingsButton: View {
  enum TrailingIcon {
    case openOutside, chevron
  }

  let icon: Image
  let iconBGColor: Color
  let title: String
  var trailingText: String?
  var indicator: TrailingIcon?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: .grid(3)) {
        icon
          .font(.footnote)
          .foregroundColor(.DS.Text.base)
          .frame(width: 28, height: 28)
          .background(iconBGColor)
          .cornerRadius(6)

        Text(title)
          .foregroundColor(.DS.Text.base)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let trailingText {
          Text(trailingText)
            .foregroundColor(.DS.Text.subdued)
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
  let icon: Image
  let iconBGColor: Color
  let title: String
  var trailingText: String? = nil
  var content: Content

  @State var isActive = false

  init(icon: Image, iconBGColor: Color, title: String, trailingText: String? = nil, @ViewBuilder content: @escaping () -> Content) {
    self.icon = icon
    self.iconBGColor = iconBGColor
    self.title = title
    self.trailingText = trailingText
    self.content = content()
  }

  var body: some View {
    Button(action: { isActive.toggle() }) {
      HStack(spacing: .grid(3)) {
        icon
          .font(.footnote)
          .foregroundColor(.DS.Text.base)
          .frame(width: 28, height: 28)
          .background(iconBGColor)
          .cornerRadius(6)

        Text(title)
          .foregroundColor(.DS.Text.base)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let trailingText {
          Text(trailingText)
            .foregroundColor(.DS.Text.subdued)
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
  let icon: Image
  let iconBGColor: Color
  let title: String
  var choices: [String]
  @Binding var selectedIndex: Int

  var body: some View {
    HStack(spacing: .grid(3)) {
      icon
        .font(.footnote)
        .foregroundColor(.DS.Text.base)
        .frame(width: 28, height: 28)
        .background(iconBGColor)
        .cornerRadius(6)

      Text(title)
        .foregroundColor(.DS.Text.base)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)

      Picker("", selection: $selectedIndex) {
        ForEach(Array(zip(choices.indices, choices)), id: \.1) { index, choice in
          Text(choice).tag(index)
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
  let icon: Image
  let iconBGColor: Color
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: .grid(3)) {
      icon
        .font(.footnote)
        .foregroundColor(.DS.Text.base)
        .frame(width: 28, height: 28)
        .background(iconBGColor)
        .cornerRadius(6)

      Text(title)
        .foregroundColor(.DS.Text.base)
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
