import SwiftUI

func ForEachWithIndex<Data: RandomAccessCollection>(
  _ data: Data,
  @ViewBuilder content: @escaping (Data.Index, Data.Element) -> some View
) -> some View where Data.Index: Hashable {
  ForEach(Array(zip(data.indices, data)), id: \.0) { index, element in
    content(index, element)
  }
}
