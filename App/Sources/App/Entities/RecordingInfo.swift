import AppDevUtils
import Foundation

// MARK: - RecordingInfo

public struct RecordingInfo: Identifiable, Hashable, Then, Codable {
  public var fileName: String = UUID().uuidString + ".wav"
  public var title = ""
  public var date: Date
  public var duration: TimeInterval
  public var text: String = ""
  public var isTranscribed = false

  public var id: String { fileName }
}

#if DEBUG
  extension RecordingInfo {
    static let mock = RecordingInfo(
      fileName: "mock.wav",
      title: "Random thoughts",
      date: Date(),
      duration: 10,
      text: "Mock text",
      isTranscribed: true
    )

    static let fixtures: [RecordingInfo] = [
      RecordingInfo(
        fileName: "groceryList.wav",
        title: "Grocery List",
        date: Date(),
        duration: 15,
        text: "Milk, eggs, bread, tomatoes, onions, cereal, chicken, ground beef, pasta, apples, and orange juice.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "meetingRecap.wav",
        title: "Meeting Recap",
        date: Date(),
        duration: 25,
        text: "Discussed new marketing strategy, assigned tasks to team members, follow-up meeting scheduled for next week. Bob to send updated report by Wednesday.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "weekendPlans.wav",
        title: "Weekend Plans",
        date: Date(),
        duration: 20,
        text: "Saturday morning, 10 AM - Yoga class. Afternoon - Lunch with Sarah at that new Italian place. Evening - Movie night at home. Sunday - Finish reading that book and start planning for the next road trip.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "birthdayPartyIdeas.wav",
        title: "Birthday Party Ideas",
        date: Date(),
        duration: 18,
        text: "Theme: Superheroes. Decorations: balloons, banners, and confetti. Food: pizza, chips, and ice cream. Activities: face painting, games, and a piñata.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "gymWorkoutRoutine.wav",
        title: "Gym Workout Routine",
        date: Date(),
        duration: 22,
        text: "Warm-up: 5 minutes on the treadmill. Strength training: 3 sets of 10 squats, lunges, and push-ups. Cardio: 20 minutes on the elliptical. Cool down: stretching and deep breathing exercises.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "bookRecommendations.wav",
        title: "Book Recommendations",
        date: Date(),
        duration: 17,
        text: "Educated by Tara Westover, Atomic Habits by James Clear, Sapiens by Yuval Noah Harari, and The Nightingale by Kristin Hannah.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "websiteIdeas.wav",
        title: "Website Ideas",
        date: Date(),
        duration: 19,
        text: "Online art gallery showcasing local artists, subscription-based meal planning service, educational platform for creative writing, and a marketplace for handmade crafts.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "carMaintenanceReminders.wav",
        title: "Car Maintenance Reminders",
        date: Date(),
        duration: 14,
        text: "Check oil levels and tire pressure, schedule appointment for oil change, replace wiper blades, and inspect brake pads.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "newRecipeIdeas.wav",
        title: "New Recipe Ideas",
        date: Date(),
        duration: 16,
        text: "Vegetarian stir-fry with tofu, spaghetti carbonara, Moroccan-style chicken with couscous, and homemade sushi rolls.",
        isTranscribed: true
      ),
      RecordingInfo(
        fileName: "podcastEpisodeList.wav",
        title: "Podcast Episode List",
        date: Date(),
        duration: 21,
        text: "1. How to Build a Successful Startup, 2. Exploring the Depths of Space, 3. The History of Coffee, 4. Mindfulness and Meditation Techniques, and 5. The Future of Renewable Energy.",
        isTranscribed: true
      )
    ]
  }
#endif
