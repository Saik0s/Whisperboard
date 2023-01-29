import AppDevUtils
import SwiftUI

// MARK: - ExpandableText

struct ExpandableText: View {
  @Binding var isExpanded: Bool
  @State var isTruncated: Bool = false
  @State var shrinkText: String = ""

  var text: String
  let font: UIFont
  let lineLimit: Int

  private var moreLessText: String {
    if !isTruncated {
      return ""
    } else {
      return isExpanded ? "" : "..."
    }
  }

  init(_ text: String, lineLimit: Int, font: UIFont = .preferredFont(forTextStyle: .body), isExpanded: Binding<Bool>) {
    self.text = text
    self.lineLimit = lineLimit
    self.font = font
    _isExpanded = isExpanded
    _shrinkText = State(wrappedValue: text)
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Group {
        Text(isExpanded ? text : shrinkText)
          + Text(moreLessText).foregroundColor(.DS.Text.subdued)
      }
      .lineLimit(isExpanded ? nil : lineLimit)
      .background(
        // Render the limited text and measure its size
        Text(text)
          .lineLimit(lineLimit)
          .background {
            GeometryReader { visibleTextGeometry in
              Color.clear
                .onAppear { calculateShrinkText(visibleTextGeometry: visibleTextGeometry) }
            }
          }
          .hidden() // Hide the background
      )
      .font(Font(font))
    }
    .onTapGesture {
      if isTruncated {
        withAnimation {
          isExpanded.toggle()
        }
      }
    }
  }

  private func calculateShrinkText(visibleTextGeometry: GeometryProxy) {
    let size = CGSize(width: visibleTextGeometry.size.width, height: .greatestFiniteMagnitude)
    let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: font]
    /// Binary search until mid == low && mid == high
    var low = 0
    var height = shrinkText.count
    var mid = height /// start from top so that if text contain we does not need to loop
    while (height - low) > 1 {
      let attributedText = NSAttributedString(string: shrinkText + moreLessText, attributes: attributes)
      let boundingRect = attributedText.boundingRect(with: size, options: NSStringDrawingOptions.usesLineFragmentOrigin, context: nil)
      if boundingRect.size.height > visibleTextGeometry.size.height {
        isTruncated = true
        height = mid
        mid = (height + low) / 2
      } else {
        if mid == text.count {
          break
        } else {
          low = mid
          mid = (low + height) / 2
        }
      }
      shrinkText = String(text.prefix(mid))
    }
    if isTruncated {
      shrinkText = String(shrinkText.prefix(shrinkText.count - 2)) // -2 extra as highlighted text is bold
    } else {
      isExpanded = true
    }
  }
}

// MARK: - ExpandableText_Previews

struct ExpandableText_Previews: PreviewProvider {
  static var previews: some View {
    VStack(alignment: .leading, spacing: 10) {
      ExpandableText(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut laborum",
        lineLimit: 6,
        font: .preferredFont(forTextStyle: .body),
        isExpanded: .constant(false)
      )
      ExpandableText("Small text", lineLimit: 3, font: .preferredFont(forTextStyle: .body), isExpanded: .constant(false))
      ExpandableText(
        "Render the limited text and measure its size, R",
        lineLimit: 1,
        font: .preferredFont(forTextStyle: .body),
        isExpanded: .constant(false)
      )
      ExpandableText(
        "Create a ZStack with unbounded height to allow the inner Text as much, Render the limited text and measure its size, Hide the background Indicates whether the text has been truncated in its display.",
        lineLimit: 3,
        font: .preferredFont(forTextStyle: .body),
        isExpanded: .constant(false)
      )
    }.padding()
  }
}
