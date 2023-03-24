import AppDevUtils
import SwiftUI

extension View {
  func shareSheet(item: Binding<(some Any)?>) -> some View {
    sheet(isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })) {
      ShareSheet(activityItems: item.wrappedValue.map { [$0] } ?? [])
    }
  }
}
