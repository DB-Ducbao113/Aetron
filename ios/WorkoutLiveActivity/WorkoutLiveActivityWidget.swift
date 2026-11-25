import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
      WorkoutLiveActivityLockScreenView(context: context)
        .activityBackgroundTint(Color(red: 0.03, green: 0.06, blue: 0.10).opacity(0.96))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded Leading Region
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 6) {
            Circle()
              .fill(_statusColor(context.state.status))
              .frame(width: 8, height: 8)
              .shadow(color: _statusColor(context.state.status), radius: 3)
            
            VStack(alignment: .leading, spacing: 2) {
              Text(context.attributes.workoutName.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
              Text(_statusTitle(context.state.status))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            }
          }
          .padding(.leading, 4)
        }

        // Expanded Trailing Region
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 3) {
              Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 0.16, green: 0.96, blue: 0.60))
              Text("PACE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            }
            Text(_paceText(context.state.avgSpeedKmh))
              .font(.system(size: 14, weight: .heavy, design: .monospaced))
              .foregroundStyle(Color(red: 0.16, green: 0.96, blue: 0.60))
          }
          .padding(.trailing, 4)
        }

        // Expanded Bottom Region
        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 8) {
            _IslandMetricCapsule(
              icon: "timer",
              title: "TIME",
              value: _durationText(context.state.durationSeconds),
              accentColor: .white
            )
            _IslandMetricCapsule(
              icon: "figure.run",
              title: "DISTANCE",
              value: _distanceText(context.state.distanceMeters),
              accentColor: Color(red: 0.0, green: 0.9, blue: 1.0)
            )
            _IslandMetricCapsule(
              icon: "flame.fill",
              title: "CALORIES",
              value: "\(context.state.caloriesBurned) kcal",
              accentColor: Color(red: 1.0, green: 0.45, blue: 0.3)
            )
          }
          .padding(.top, 4)
        }
      } compactLeading: {
        HStack(spacing: 4) {
          Circle()
            .fill(_statusColor(context.state.status))
            .frame(width: 6, height: 6)
          Image(systemName: "figure.run")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
        }
      } compactTrailing: {
        Text(_distanceCompactText(context.state.distanceMeters))
          .font(.system(size: 12, weight: .heavy, design: .rounded))
          .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
      } minimal: {
        Image(systemName: "figure.run")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(_statusColor(context.state.status))
      }
    }
  }
}

// MARK: - Premium Glassmorphic Lock Screen View
private struct WorkoutLiveActivityLockScreenView: View {
  let context: ActivityViewContext<WorkoutLiveActivityAttributes>

  var body: some View {
    VStack(spacing: 12) {
      // 1. Top Header Row: Status Badge + Workout Title & Aetron Logo
      HStack(alignment: .center) {
        HStack(spacing: 6) {
          // Pulsing Glow Indicator
          ZStack {
            Circle()
              .fill(_statusColor(context.state.status).opacity(0.3))
              .frame(width: 16, height: 16)
            Circle()
              .fill(_statusColor(context.state.status))
              .frame(width: 8, height: 8)
          }

          Text(_statusTitle(context.state.status).uppercased())
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(_statusColor(context.state.status))
            .tracking(0.6)

          Text("•")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white.opacity(0.3))

          Text(context.attributes.workoutName.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
            .tracking(0.8)
        }

        Spacer()

        // Sleek App Badge
        HStack(spacing: 5) {
          Text("AETRON")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
            .tracking(1.0)
          
          _AppLogoBadge(size: 18, cornerRadius: 5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.06), in: Capsule())
      }

      // 2. Center Hero Stat Row: Big Distance & Big Time
      HStack(alignment: .lastTextBaseline, spacing: 14) {
        // Main Metric: Distance (Huge, High Contrast)
        VStack(alignment: .leading, spacing: 1) {
          Text("DISTANCE")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.45))
            .tracking(1.0)

          HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(_distanceNumberOnly(context.state.distanceMeters))
              .font(.system(size: 38, weight: .black, design: .rounded))
              .foregroundStyle(
                LinearGradient(
                  colors: [
                    Color.white,
                    Color(red: 0.8, green: 0.98, blue: 1.0)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )

            Text("KM")
              .font(.system(size: 14, weight: .black, design: .rounded))
              .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
          }
        }

        Spacer()

        // Secondary Hero: Pace Badge
        VStack(alignment: .trailing, spacing: 3) {
          Text("CURRENT PACE")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.45))
            .tracking(0.8)

          HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
              .font(.system(size: 12, weight: .black))
              .foregroundStyle(Color(red: 0.16, green: 0.96, blue: 0.60))

            Text(_paceText(context.state.avgSpeedKmh))
              .font(.system(size: 20, weight: .black, design: .monospaced))
              .foregroundStyle(Color(red: 0.16, green: 0.96, blue: 0.60))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(
            Color(red: 0.16, green: 0.96, blue: 0.60).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(Color(red: 0.16, green: 0.96, blue: 0.60).opacity(0.3), lineWidth: 1)
          )
        }
      }

      // 3. Bottom 3-Metric Glass Capsule Row
      HStack(spacing: 8) {
        _LockScreenMetricCard(
          icon: "stopwatch.fill",
          title: "TIME",
          value: _durationText(context.state.durationSeconds),
          accentColor: .white
        )

        _LockScreenMetricCard(
          icon: "speedometer",
          title: "AVG SPEED",
          value: String(format: "%.1f km/h", context.state.avgSpeedKmh),
          accentColor: Color(red: 0.0, green: 0.9, blue: 1.0)
        )

        _LockScreenMetricCard(
          icon: "flame.fill",
          title: "CALORIES",
          value: "\(context.state.caloriesBurned) kcal",
          accentColor: Color(red: 1.0, green: 0.5, blue: 0.3)
        )
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      ZStack {
        // Deep Obsidian Radial Cyber Background
        Color(red: 0.03, green: 0.06, blue: 0.10)
        
        RadialGradient(
          colors: [
            Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.08),
            Color.clear
          ],
          center: .topLeading,
          startRadius: 0,
          endRadius: 180
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [
              Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.4),
              Color.white.opacity(0.08),
              Color(red: 0.16, green: 0.96, blue: 0.60).opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1.2
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

// MARK: - Lock Screen Metric Card Component
private struct _LockScreenMetricCard: View {
  let icon: String
  let title: String
  let value: String
  let accentColor: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(accentColor)
        
        Text(title)
          .font(.system(size: 9, weight: .black, design: .rounded))
          .foregroundStyle(.white.opacity(0.5))
          .tracking(0.6)
      }

      Text(value)
        .font(.system(size: 13, weight: .heavy, design: .monospaced))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
    )
  }
}

// MARK: - Dynamic Island Metric Capsule Component
private struct _IslandMetricCapsule: View {
  let icon: String
  let title: String
  let value: String
  let accentColor: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 3) {
        Image(systemName: icon)
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(accentColor)
        Text(title)
          .font(.system(size: 8, weight: .heavy, design: .rounded))
          .foregroundStyle(.white.opacity(0.5))
      }
      Text(value)
        .font(.system(size: 11, weight: .heavy, design: .monospaced))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
  }
}

// MARK: - App Logo Badge
private struct _AppLogoBadge: View {
  var size: CGFloat = 24
  var cornerRadius: CGFloat = 8

  var body: some View {
    Image("LiveActivityLogo")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
  }
}

// MARK: - Helpers
private func _statusTitle(_ status: String) -> String {
  switch status.lowercased() {
  case "paused":
    return "Paused"
  case "ended":
    return "Finished"
  default:
    return "Recording"
  }
}

private func _statusColor(_ status: String) -> Color {
  switch status.lowercased() {
  case "paused":
    return Color(red: 1.0, green: 0.72, blue: 0.2) // Amber
  case "ended":
    return Color(red: 0.16, green: 0.96, blue: 0.60) // Mint
  default:
    return Color(red: 0.16, green: 0.96, blue: 0.60) // Live Green/Mint
  }
}

private func _durationText(_ seconds: Int) -> String {
  let hours = seconds / 3600
  let minutes = (seconds % 3600) / 60
  let remainingSeconds = seconds % 60
  if hours > 0 {
    return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
  }
  return String(format: "%02d:%02d", minutes, remainingSeconds)
}

private func _distanceNumberOnly(_ meters: Double) -> String {
  let distanceKm = meters / 1000.0
  return String(format: "%.2f", distanceKm)
}

private func _distanceText(_ meters: Double) -> String {
  let distanceKm = meters / 1000.0
  return String(format: "%.2f km", distanceKm)
}

private func _distanceCompactText(_ meters: Double) -> String {
  let distanceKm = meters / 1000.0
  return String(format: "%.1f km", distanceKm)
}

private func _paceText(_ kmh: Double) -> String {
  if kmh <= 0.05 {
    return "--"
  }
  let totalSeconds = Int((3600.0 / kmh).rounded())
  let minutes = totalSeconds / 60
  let seconds = totalSeconds % 60
  return String(format: "%d'%02d\"", minutes, seconds)
}
