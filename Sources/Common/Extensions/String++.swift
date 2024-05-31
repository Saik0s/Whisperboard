import Foundation

public extension String {
  var lastPathComponent: String {
    components(separatedBy: "/").last ?? self
  }

  var pathToLastComponent: String {
    components(separatedBy: "/").dropLast().joined(separator: "/")
  }

  func appendingPathComponent(_ component: String) -> String {
    hasSuffix("/")
      ? appending(component)
      : appending("/" + component)
  }

  mutating func firstCharacterUppercased() {
    guard let first else {
      return
    }
    self = String(first).uppercased() + dropFirst()
  }
}

public extension StaticString {
  var lastPathComponent: String {
    "\(self)".lastPathComponent
  }

  var pathToLastComponent: String {
    "\(self)".pathToLastComponent
  }
}

public extension String {
  func replacingOccurrences(
    ofPattern pattern: String,
    withTemplate template: String,
    options: String.CompareOptions = [.regularExpression],
    range searchRange: Range<Self.Index>? = nil
  ) -> String {
    assert(
      options.isStrictSubset(of: [.regularExpression, .anchored, .caseInsensitive]),
      "Invalid options for regular expression replacement"
    )

    return replacingOccurrences(
      of: pattern,
      with: template,
      options: options.union(.regularExpression),
      range: searchRange
    )
  }
}

public extension String {
  static func randomWord(length: Int = .random(in: 2 ... 10)) -> String {
    let kCons = 1
    let kVows = 2

    var cons: [String] = [
      // single consonants. Beware of Q, it"s often awkward in words
      "b", "c", "d", "f", "g", "h", "j", "k", "l", "m",
      "n", "p", "r", "s", "t", "v", "w", "x", "z",
      // possible combinations excluding those which cannot start a word
      "pt", "gl", "gr", "ch", "ph", "ps", "sh", "st", "th", "wh",
    ]

    // consonant combinations that cannot start a word
    let consCantStart: [String] = [
      "ck", "cm",
      "dr", "ds",
      "ft",
      "gh", "gn",
      "kr", "ks",
      "ls", "lt", "lr",
      "mp", "mt", "ms",
      "ng", "ns",
      "rd", "rg", "rs", "rt",
      "ss",
      "ts", "tch",
    ]

    let vows: [String] = [
      // single vowels
      "a", "e", "i", "o", "u", "y",
      // vowel combinations your language allows
      "ee", "oa", "oo",
    ]

    // start by vowel or consonant ?
    var current = Bool.random() ? kCons : kVows

    var word = ""
    while word.count < length {
      // After first letter, use all consonant combos
      if word.count == 2 {
        cons += consCantStart
      }

      // random sign from either $cons or $vows
      var rnd = ""
      var index: Int
      if current == kCons {
        index = Int.random(in: 0 ..< cons.count)
        rnd = cons[index]
      } else if current == kVows {
        index = Int.random(in: 0 ..< vows.count)
        rnd = vows[index]
      }

      // check if random sign fits in word length
      let tempWord = "\(word)\(rnd)"
      if tempWord.count <= length {
        word = "\(word)\(rnd)"
        // alternate sounds
        current = (current == kCons) ? kVows : kCons
      }
    }

    return word
  }

  public static func randomSentence(wordsCount: Int = 10, firstCapital: Bool = true, addPeriod: Bool = true) -> String {
    var sentence = (0 ..< wordsCount)
      .map { _ in String.randomWord(length: .random(in: 2 ... 10)) }
      .joined(separator: " ")

    if firstCapital {
      sentence.firstCharacterUppercased()
    }

    if addPeriod {
      sentence.append(".")
    }

    return sentence
  }

  var titleCased: String {
    replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression, range: range(of: self))
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .capitalized
  }

  func deletingPrefix(_ prefix: String) -> String {
    guard hasPrefix(prefix) else {
      return self
    }
    return String(dropFirst(prefix.count))
  }

  var onlyDigitsAndPlus: String {
    replacingOccurrences(ofPattern: "[^\\d+\\+]", withTemplate: "")
  }
}
