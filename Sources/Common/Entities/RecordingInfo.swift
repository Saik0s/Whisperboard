import Foundation

// MARK: - RecordingInfo

public struct RecordingInfo: Identifiable, Hashable, Then {
  public var id: String { fileName }

  public var fileName: String
  public var title = ""
  public var date: Date
  public var duration: TimeInterval
  public var editedText: String?
  public var transcription: Transcription?

  public var text: String { editedText ?? transcription?.text ?? "" }
  public var isTranscribed: Bool { transcription?.status.isDone == true }
  public var isTranscribing: Bool { transcription?.status.isLoadingOrProgress == true }
  public var isPaused: Bool { transcription?.status.isPaused == true }
  public var transcriptionErrorMessage: String? { transcription?.status.errorMessage }

  public var segments: [Segment] { transcription?.segments ?? [] }
  public var offset: Int64 { segments.last?.endTime ?? 0 }
  public var progress: Double { Double(offset) / Double(duration * 1000) }

  public init(
    fileName: String,
    title: String = "",
    date: Date,
    duration: TimeInterval,
    editedText: String? = nil,
    transcription: Transcription? = nil
  ) {
    self.fileName = fileName
    self.title = title
    self.date = date
    self.duration = duration
    self.editedText = editedText
    self.transcription = transcription
  }
}

// MARK: Codable

extension RecordingInfo: Codable {
  enum CodingKeys: String, CodingKey {
    case fileName, title, date, duration, editedText, transcription
    case transcriptionHistory // this for migration
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    fileName = try container.decode(String.self, forKey: .fileName)
    title = try container.decode(String.self, forKey: .title)
    date = try container.decode(Date.self, forKey: .date)
    duration = try container.decode(TimeInterval.self, forKey: .duration)
    editedText = try container.decodeIfPresent(String.self, forKey: .editedText)

    // Migration logic
    if let transcriptionHistory = try? container.decodeIfPresent([Transcription].self, forKey: .transcriptionHistory) {
      transcription = transcriptionHistory.last
    } else {
      transcription = try container.decodeIfPresent(Transcription.self, forKey: .transcription)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(fileName, forKey: .fileName)
    try container.encode(title, forKey: .title)
    try container.encode(date, forKey: .date)
    try container.encode(duration, forKey: .duration)
    try container.encodeIfPresent(editedText, forKey: .editedText)
    try container.encodeIfPresent(transcription, forKey: .transcription)
  }
}

public extension RecordingInfo {
  var fileURL: URL {
    Configs.recordingsDirectoryURL.appending(path: fileName)
  }

  var waveformImageURL: URL {
    Configs.recordingsDirectoryURL.appending(path: fileName + ".waveform.png")
  }
}

public extension RecordingInfo {
  init(id: String, title: String, date: Date, duration: TimeInterval) {
    fileName = "\(id).wav"
    self.title = title
    self.date = date
    self.duration = duration
  }

  init(fileName: String, title: String, date: Date, duration: TimeInterval) {
    self.fileName = fileName
    self.title = title
    self.date = date
    self.duration = duration
  }
}

#if DEBUG

  public extension RecordingInfo {
    static let mock = RecordingInfo(
      fileName: "mock.wav",
      title: "Random thoughts",
      date: Date(),
      duration: 10,
      editedText: "Mock text",
      transcription: .mock1
    )

    static let fixtures: [RecordingInfo] = [
      RecordingInfo(
        fileName: "groceryList.wav",
        title: "Grocery List",
        date: Date(),
        duration: 15,
        editedText: "Milk, eggs, bread, tomatoes, onions, cereal, chicken, ground beef, pasta, apples, and orange juice.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "notTranscribed.wav",
        title: "Not Transcribed",
        date: Date(),
        duration: 120,
        transcription: nil
      ),
      RecordingInfo(
        fileName: "meetingRecap.wav",
        title: "Meeting Recap",
        date: Date(),
        duration: 25,
        editedText: "Discussed new marketing strategy, assigned tasks to team members, follow-up meeting scheduled for next week. Bob to send updated report by Wednesday.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "weekendPlans.wav",
        title: "Weekend Plans",
        date: Date(),
        duration: 20,
        editedText: "Saturday morning, 10 AM - Yoga class. Afternoon - Lunch with Sarah at that new Italian place. Evening - Movie night at home. Sunday - Finish reading that book and start planning for the next road trip.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "birthdayPartyIdeas.wav",
        title: "Birthday Party Ideas",
        date: Date(),
        duration: 18,
        editedText: "Theme: Superheroes. Decorations: balloons, banners, and confetti. Food: pizza, chips, and ice cream. Activities: face painting, games, and a piñata.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "gymWorkoutRoutine.wav",
        title: "Gym Workout Routine",
        date: Date(),
        duration: 22,
        editedText: "Warm-up: 5 minutes on the treadmill. Strength training: 3 sets of 10 squats, lunges, and push-ups. Cardio: 20 minutes on the elliptical. Cool down: stretching and deep breathing exercises.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "bookRecommendations.wav",
        title: "Book Recommendations",
        date: Date(),
        duration: 17,
        editedText: "Educated by Tara Westover, Atomic Habits by James Clear, Sapiens by Yuval Noah Harari, and The Nightingale by Kristin Hannah.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "websiteIdeas.wav",
        title: "Website Ideas",
        date: Date(),
        duration: 19,
        editedText: "Online art gallery showcasing local artists, subscription-based meal planning service, educational platform for creative writing, and a marketplace for handmade crafts.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "carMaintenanceReminders.wav",
        title: "Car Maintenance Reminders",
        date: Date(),
        duration: 14,
        editedText: "Check oil levels and tire pressure, schedule appointment for oil change, replace wiper blades, and inspect brake pads.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "newRecipeIdeas.wav",
        title: "New Recipe Ideas",
        date: Date(),
        duration: 16,
        editedText: "Vegetarian stir-fry with tofu, spaghetti carbonara, Moroccan-style chicken with couscous, and homemade sushi rolls.",
        transcription: .mock1
      ),
      RecordingInfo(
        fileName: "podcastEpisodeList.wav",
        title: "Podcast Episode List",
        date: Date(),
        duration: 21,
        editedText: "1. How to Build a Successful Startup, 2. Exploring the Depths of Space, 3. The History of Coffee, 4. Mindfulness and Meditation Techniques, and 5. The Future of Renewable Energy.",
        transcription: .mock1
      ),
    ]
  }
#endif
