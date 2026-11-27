import ActivityKit
import Foundation

struct WorkoutLiveActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var activityType: String
    var trackingMode: String
    var status: String
    var durationSeconds: Int
    var distanceMeters: Double
    var avgSpeedKmh: Double
    var caloriesBurned: Int
    var useMetricUnits: Bool = true
    var languageCode: String = "vi"
    var updatedAt: Date
  }

  var workoutName: String
}
