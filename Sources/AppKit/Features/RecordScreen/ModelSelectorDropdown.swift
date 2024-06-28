import Common
import SwiftUI

struct ModelSelectorDropdown: View {
  @Binding var selectedModel: Model.ID
  let availableModels: [Model]
  let isEnabled: Bool

  var body: some View {
    Picker("Model", selection: $selectedModel) {
      ForEach(availableModels) { model in
        Text(model.name).tag(model.id)
      }
    }
    .pickerStyle(MenuPickerStyle())
    .disabled(!isEnabled)
  }
}
