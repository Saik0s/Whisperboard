import SwiftUI

// MARK: - Font.DS

extension Font {
  enum DS {
    static var action: Font {
      WhisperBoardKitFontFamily.Poppins.semiBold.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .body).pointSize)
    }

    static var actionSecondary: Font {
      WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .body).pointSize)
    }

    static var body: Font {
      WhisperBoardKitFontFamily.Karla.regular.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .body).pointSize)
    }

    static var bodyBold: Font {
      WhisperBoardKitFontFamily.Karla.bold.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .body).pointSize)
    }

    static var caption: Font {
      WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .caption1).pointSize)
    }

    static var captionBold: Font {
      WhisperBoardKitFontFamily.Poppins.bold.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .caption1).pointSize)
    }

    static var footnote: Font {
      WhisperBoardKitFontFamily.Poppins.regular.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .footnote).pointSize)
    }

    static var badge: Font {
      WhisperBoardKitFontFamily.Poppins.semiBold.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .caption2).pointSize)
    }

    static var title: Font {
      WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .title1).pointSize)
    }

    static var titleSmall: Font {
      WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .title2).pointSize)
    }

    static var titleBold: Font {
      WhisperBoardKitFontFamily.Poppins.bold.swiftUIFont(size: UIFont.preferredFont(forTextStyle: .title1).pointSize)
    }
  }
}

// MARK: - TextStyle

struct TextStyle {
  let font: Font
  let lineSpacing: CGFloat
  let foregroundColor: Color
  let kerning: CGFloat
}

extension TextStyle {
  static let body = TextStyle(font: Font.DS.body, lineSpacing: 3, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let bodyBold = TextStyle(font: Font.DS.bodyBold, lineSpacing: 3, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let caption = TextStyle(font: Font.DS.caption, lineSpacing: 2, foregroundColor: Color.DS.Text.subdued, kerning: 0)
  static let captionBase = TextStyle(font: Font.DS.footnote, lineSpacing: 2, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let footnote = TextStyle(font: Font.DS.footnote, lineSpacing: 1, foregroundColor: Color.DS.Text.subdued, kerning: 0)
  static let smallIcon = TextStyle(font: Font.DS.footnote, lineSpacing: 4, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let headline = TextStyle(font: Font.DS.bodyBold, lineSpacing: 3, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let label = TextStyle(font: Font.DS.body, lineSpacing: 5, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let sublabel = TextStyle(font: Font.DS.body, lineSpacing: 3, foregroundColor: Color.DS.Text.subdued, kerning: 0)
  static let error = TextStyle(font: Font.DS.caption, lineSpacing: 5, foregroundColor: Color.DS.Text.error, kerning: 0)
  static let navigationBarButton = TextStyle(font: Font.DS.actionSecondary, lineSpacing: 6, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let navigationTitle = TextStyle(font: Font.DS.title, lineSpacing: 11, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let primaryButton = TextStyle(font: Font.DS.action, lineSpacing: 7, foregroundColor: Color.DS.Text.overAccent, kerning: 0)
  static let secondaryButton = TextStyle(font: Font.DS.actionSecondary, lineSpacing: 6, foregroundColor: Color.DS.Text.base, kerning: 0)
  static let subheadline = TextStyle(font: Font.DS.body, lineSpacing: 3, foregroundColor: Color.DS.Text.subdued, kerning: 0)
}

extension TextStyle {
  func apply(to text: some View) -> some View {
    text
      .font(font)
      .lineSpacing(lineSpacing)
      .foregroundColor(foregroundColor)
      .kerning(kerning)
  }
}

extension View {
  func textStyle(_ style: TextStyle) -> some View {
    style.apply(to: self)
  }
}
