//
// Fonts.swift
//

import SwiftUI

// MARK: - Font.DS

public extension Font {
  enum DS {
    public static let titleXL = Font.system(.largeTitle, design: .rounded, weight: .regular)
    public static let titleL = Font.system(.title, design: .rounded, weight: .regular)
    public static let titleM = Font.system(.title2, design: .rounded, weight: .regular)
    public static let titleS = Font.system(.title3, design: .rounded, weight: .medium)
    public static let bodyL = Font.system(.title3, design: .rounded, weight: .regular)
    public static let bodyM = Font.system(.body, design: .rounded, weight: .regular)
    public static let bodyS = Font.system(.callout, design: .rounded, weight: .regular)
    public static let footnote = Font.system(.footnote, design: .rounded, weight: .light)
    public static let date = Font.system(.footnote, design: .monospaced, weight: .regular)
  }
}

// MARK: - UIFont.DS

public extension UIFont {
  enum DS {
    public static let titleXL = UIFont.preferredFont(forTextStyle: .largeTitle).with(design: .rounded, weight: .regular)
    public static let titleL = UIFont.preferredFont(forTextStyle: .title1).with(design: .rounded, weight: .regular)
    public static let titleM = UIFont.preferredFont(forTextStyle: .title2).with(design: .rounded, weight: .regular)
    public static let titleS = UIFont.preferredFont(forTextStyle: .title3).with(design: .rounded, weight: .medium)
    public static let bodyL = UIFont.preferredFont(forTextStyle: .title3).with(design: .rounded, weight: .regular)
    public static let bodyM = UIFont.preferredFont(forTextStyle: .body).with(design: .rounded, weight: .regular)
    public static let bodyS = UIFont.preferredFont(forTextStyle: .callout).with(design: .rounded, weight: .regular)
    public static let footnote = UIFont.preferredFont(forTextStyle: .footnote).with(design: .rounded, weight: .light)
    public static let date = UIFont.preferredFont(forTextStyle: .footnote).with(design: .monospaced, weight: .regular)
  }
}

extension UIFont {
  func with(design: UIFontDescriptor.SystemDesign, weight: UIFont.Weight) -> UIFont {
    var newDescriptor = fontDescriptor
      .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
    newDescriptor = newDescriptor.withDesign(design) ?? newDescriptor
    return UIFont(descriptor: newDescriptor, size: pointSize)
  }
}
