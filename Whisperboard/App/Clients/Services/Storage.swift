//
// Storage.swift
//

import AVFoundation
import ComposableArchitecture
import Dependencies
import Foundation
import XCTestDynamicOverlay

// struct WhisperInfo: Identifiable, Codable, Hashable {
//   var id: URL { fileURL }
//   let fileURL: URL
//   let text: String
//
//   var date: Date {
//     fileURL
//       .lastPathComponent
//       .split(separator: ".")
//       .first
//       .map { fileNameDateFormatter.date(from: "\($0)") }
//       .flatMap({ $0 })
//       ?? Date()
//   }
//
//   var duration: Double {
//     let asset = AVURLAsset(url: fileURL, options: nil)
//
//     let semaphore = DispatchSemaphore(value: 0)
//
//     class Box<T> {
//       var value: T
//       init(value: T) { self.value = value }
//     }
//
//     let boxedDuration = Box<Double>(value: 0)
//     Task {
//       let (duration, _) = try await asset.load(.duration, .metadata)
//       boxedDuration.value = Double(duration.value) / Double(duration.timescale)
//       semaphore.signal()
//     }
//
//     semaphore.wait()
//     return boxedDuration.value
//   }
//
//   var asWhisper: Whisper.State {
//     Whisper.State(date: date, duration: duration, url: fileURL)
//   }
// }

typealias WhisperInfo = Whisper.State

// MARK: - Storage

struct Storage {
  var read: @Sendable () async throws -> IdentifiedArrayOf<WhisperInfo>
  var write: @Sendable (IdentifiedArrayOf<WhisperInfo>) async throws -> Void
  var cleanup: @Sendable () async throws -> Void
  var createNewWhisperURL: () -> URL
  var fileURLWithName: (String) -> URL
}

// MARK: TestDependencyKey

extension Storage: TestDependencyKey {
  static let previewValue = Self(
    read: {
      [
        Whisper.State(
          date: Date(),
          duration: .random(in: 1 ... 10),
          mode: .notPlaying,
          title: "",
          fileName: "test1",
          text: "Lorem ipsum",
          isTranscribed: true
        ),
        Whisper.State(
          date: Date(),
          duration: .random(in: 1 ... 10),
          mode: .notPlaying,
          title: "",
          fileName: "test2",
          text: Array(repeating: "Lorem ipsum ", count: 30).joined(),
          isTranscribed: true
        ),
      ]
    },
    write: { _ in },
    cleanup: {},
    createNewWhisperURL: { URL(filePath: "~/Downloads/1.wav") },
    fileURLWithName: { _ in URL(filePath: "~/Downloads/1.wav") }
  )

  static let testValue = Self(
    read: unimplemented("\(Self.self).read"),
    write: unimplemented("\(Self.self).write"),
    cleanup: unimplemented("\(Self.self).cleanup"),
    createNewWhisperURL: unimplemented("\(Self.self).createNewWhisperURL"),
    fileURLWithName: unimplemented("\(Self.self).fileURLWithName")
  )
}

// MARK: DependencyKey

extension Storage: DependencyKey {
  static let liveValue: Self = {
    let docURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

    @Sendable
    func read() async throws -> IdentifiedArrayOf<WhisperInfo> {
      log("Reading stored whispers")
      guard let data = UserDefaults.standard.object(forKey: "whispers") as? Data else { return [] }
      let whispers = try JSONDecoder().decode([WhisperInfo].self, from: data).identifiedArray
      let filtered = whispers.filter { whisper in
        FileManager.default.fileExists(atPath: docURL.appending(path: whisper.fileName).path)
      }
      log("whispers:", whispers.count, "filtered:", filtered.count)
      return filtered
    }

    @Sendable
    func write(_ whispers: IdentifiedArrayOf<WhisperInfo>) async throws {
      let filtered = whispers.filter { whisper in
        FileManager.default.fileExists(atPath: docURL.appending(path: whisper.fileName).path)
      }
      let data = try JSONEncoder().encode(filtered.elements)
      UserDefaults.standard.set(data, forKey: "whispers")
    }

    return Self(
      read: {
        try await read()
      },
      write: { whispers in
        try await write(whispers)
      },
      cleanup: {
        let content = try FileManager.default.contentsOfDirectory(atPath: docURL.path)
        let whispers = try await read()
        try content.forEach { name in
          if whispers.contains(where: { whisper in whisper.fileName == name }) == false {
            let fileURL = docURL.appending(path: name)
            log("Removing file", fileURL)
            try FileManager.default.removeItem(at: fileURL)
          }
        }
        try await write(whispers.filter { whisper in
          FileManager.default.fileExists(atPath: docURL.appending(path: whisper.fileName).path)
        })
      },
      createNewWhisperURL: {
        let filename = fileNameDateFormatter.string(from: Date()) + ".wav"
        let url = docURL.appending(path: filename)
        log("New file url", url)
        return url
      },
      fileURLWithName: { name in
        docURL.appending(path: name)
      }
    )
  }()
}

extension DependencyValues {
  var storage: Storage {
    get { self[Storage.self] }
    set { self[Storage.self] = newValue }
  }
}
