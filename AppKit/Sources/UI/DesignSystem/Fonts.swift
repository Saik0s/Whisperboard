import SwiftUI

// MARK: - Font.DS

extension Font {
  enum DS {
    static let action = WhisperBoardKitFontFamily.Poppins.semiBold.swiftUIFont(size: 16)
    static let actionSecondary = WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: 16)
    static let body = WhisperBoardKitFontFamily.Karla.regular.swiftUIFont(size: 17)
    static let bodyBold = WhisperBoardKitFontFamily.Karla.bold.swiftUIFont(size: 17)
    static let caption = WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: 15)
    static let captionBold = WhisperBoardKitFontFamily.Poppins.bold.swiftUIFont(size: 15)
    static let footnote = WhisperBoardKitFontFamily.Poppins.regular.swiftUIFont(size: 12)
    static let badge = WhisperBoardKitFontFamily.Poppins.semiBold.swiftUIFont(size: 10)
    static let title = WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: 22)
    static let titleSmall = WhisperBoardKitFontFamily.Poppins.medium.swiftUIFont(size: 18)
  }
}
