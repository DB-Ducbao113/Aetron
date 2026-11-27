import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Aetron Glassline Dark Palette (aligned with Flutter KineticColors.dark & AetronLogoDrawScreen)
private enum _AetronPalette {
  static let background = Color(red: 0.047, green: 0.078, blue: 0.125)      // #0C1420
  static let surface = Color(red: 0.098, green: 0.153, blue: 0.212)         // #192736
  static let brandAccent = Color(red: 0.576, green: 0.749, blue: 1.0)       // #93BFFF (Startup dark mark/AE)
  static let frostInk = Color(red: 0.953, green: 0.969, blue: 1.0)          // #F3F7FF (Startup dark TRON/ink)
  static let mutedInk = Color(red: 0.580, green: 0.667, blue: 0.761)        // #94AAC2
  static let glassBorder = Color(red: 0.714, green: 0.863, blue: 1.0)       // #B6DCFF
  static let activeEmerald = Color(red: 0.204, green: 0.827, blue: 0.600)   // #34D399
  static let pausedAmber = Color(red: 0.961, green: 0.620, blue: 0.043)     // #F59E0B
  static let caloriesCoral = Color(red: 0.984, green: 0.573, blue: 0.235)   // #FB923C
}

struct WorkoutLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
      WorkoutLiveActivityLockScreenView(context: context)
        .activityBackgroundTint(_AetronPalette.background.opacity(0.96))
        .activitySystemActionForegroundColor(_AetronPalette.frostInk)
    } dynamicIsland: { context in
      let state = context.state
      let isVi = _isVietnamese(state.languageCode)
      let isCycling = _isCycling(state.activityType)
      let metric = state.useMetricUnits

      return DynamicIsland {
        // Expanded Leading Region: Status + Localized Sport Name
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 6) {
            Circle()
              .fill(_statusColor(state.status))
              .frame(width: 8, height: 8)
              .shadow(color: _statusColor(state.status).opacity(0.6), radius: 3)

            VStack(alignment: .leading, spacing: 2) {
              Text(_activityTitle(state.activityType, isVi: isVi).uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(_AetronPalette.brandAccent)
                .tracking(0.6)
              Text(_statusTitle(state.status, isVi: isVi))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(_AetronPalette.frostInk)
            }
          }
          .padding(.leading, 4)
        }

        // Expanded Trailing Region: Aetron Logo Mark + Primary Pace/Speed
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 4) {
              _AetronVectorMark(size: 12, color: _AetronPalette.brandAccent)
              Text(isCycling ? (isVi ? "TỐC ĐỘ" : "SPEED") : (isVi ? "NHỊP ĐỘ" : "PACE"))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(_AetronPalette.mutedInk)
                .tracking(0.5)
            }
            Text(
              isCycling
                ? _speedText(state.avgSpeedKmh, useMetric: metric)
                : _paceText(state.avgSpeedKmh, useMetric: metric)
            )
            .font(.system(size: 14, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(_AetronPalette.brandAccent)
          }
          .padding(.trailing, 4)
        }

        // Expanded Bottom Region: 3 Glassline Metric Capsules
        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 8) {
            _IslandMetricCapsule(
              icon: "timer",
              title: isVi ? "THỜI GIAN" : "TIME",
              value: _durationText(state.durationSeconds),
              accentColor: _AetronPalette.frostInk
            )
            _IslandMetricCapsule(
              icon: _activitySymbol(state.activityType),
              title: isVi ? "QUÃNG ĐƯỜNG" : "DISTANCE",
              value: _distanceText(state.distanceMeters, useMetric: metric),
              accentColor: _AetronPalette.brandAccent
            )
            _IslandMetricCapsule(
              icon: "flame.fill",
              title: isVi ? "CALO" : "CALORIES",
              value: "\(state.caloriesBurned) kcal",
              accentColor: _AetronPalette.caloriesCoral
            )
          }
          .padding(.top, 4)
        }
      } compactLeading: {
        HStack(spacing: 4) {
          Circle()
            .fill(_statusColor(state.status))
            .frame(width: 6, height: 6)
          Image(systemName: _activitySymbol(state.activityType))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(_AetronPalette.brandAccent)
        }
      } compactTrailing: {
        Text(_distanceCompactText(state.distanceMeters, useMetric: metric))
          .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(_AetronPalette.frostInk)
      } minimal: {
        _AetronVectorMark(
          size: 14,
          color: state.status.lowercased() == "paused"
            ? _AetronPalette.pausedAmber
            : _AetronPalette.brandAccent
        )
      }
    }
  }
}

// MARK: - Glassline Lock Screen View
private struct WorkoutLiveActivityLockScreenView: View {
  let context: ActivityViewContext<WorkoutLiveActivityAttributes>

  var body: some View {
    let state = context.state
    let isVi = _isVietnamese(state.languageCode)
    let isCycling = _isCycling(state.activityType)
    let metric = state.useMetricUnits

    VStack(spacing: 12) {
      // 1. Top Header Row: Status + Activity Title & Unified AETRON Startup Lockup
      HStack(alignment: .center, spacing: 8) {
        HStack(spacing: 6) {
          ZStack {
            Circle()
              .fill(_statusColor(state.status).opacity(0.24))
              .frame(width: 14, height: 14)
            Circle()
              .fill(_statusColor(state.status))
              .frame(width: 7, height: 7)
          }

          Text(_statusTitle(state.status, isVi: isVi).uppercased())
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            .foregroundStyle(_statusColor(state.status))
            .tracking(0.5)

          Text("·")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(_AetronPalette.mutedInk.opacity(0.6))

          Text(_activityTitle(state.activityType, isVi: isVi).uppercased())
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(_AetronPalette.frostInk.opacity(0.88))
            .tracking(0.6)
            .lineLimit(1)
        }

        Spacer(minLength: 6)

        _AetronLiveBrandBadge()
      }

      // 2. Center Hero Stat Row: Distance + Pace/Speed Glass Pill
      HStack(alignment: .lastTextBaseline, spacing: 14) {
        VStack(alignment: .leading, spacing: 2) {
          Text(isVi ? "QUÃNG ĐƯỜNG" : "DISTANCE")
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundStyle(_AetronPalette.mutedInk)
            .tracking(0.8)

          HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text(_distanceNumberOnly(state.distanceMeters, useMetric: metric))
              .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
              .foregroundStyle(_AetronPalette.frostInk)

            Text(metric ? "KM" : "MI")
              .font(.system(size: 13, weight: .heavy, design: .rounded))
              .foregroundStyle(_AetronPalette.brandAccent)
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text(
            isCycling
              ? (isVi ? "TỐC ĐỘ TB" : "AVG SPEED")
              : (isVi ? "NHỊP ĐỘ TB" : "AVG PACE")
          )
          .font(.system(size: 9.5, weight: .bold, design: .rounded))
          .foregroundStyle(_AetronPalette.mutedInk)
          .tracking(0.8)

          HStack(spacing: 5) {
            Image(systemName: isCycling ? "speedometer" : "bolt.fill")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(_AetronPalette.brandAccent)

            Text(
              isCycling
                ? _speedText(state.avgSpeedKmh, useMetric: metric)
                : _paceText(state.avgSpeedKmh, useMetric: metric)
            )
            .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(_AetronPalette.frostInk)
          }
          .padding(.horizontal, 11)
          .padding(.vertical, 5)
          .background(
            _AetronPalette.brandAccent.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
              .stroke(_AetronPalette.glassBorder.opacity(0.28), lineWidth: 0.9)
          )
        }
      }

      // 3. Bottom 3-Metric Glassline Capsule Row
      HStack(spacing: 8) {
        _LockScreenMetricCard(
          icon: "stopwatch.fill",
          title: isVi ? "THỜI GIAN" : "TIME",
          value: _durationText(state.durationSeconds),
          accentColor: _AetronPalette.brandAccent
        )

        _LockScreenMetricCard(
          icon: isCycling ? _activitySymbol(state.activityType) : "speedometer",
          title: isVi ? "TỐC ĐỘ TB" : "AVG SPEED",
          value: _speedText(state.avgSpeedKmh, useMetric: metric),
          accentColor: _AetronPalette.brandAccent
        )

        _LockScreenMetricCard(
          icon: "flame.fill",
          title: isVi ? "CALO" : "CALORIES",
          value: "\(state.caloriesBurned) kcal",
          accentColor: _AetronPalette.caloriesCoral
        )
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      ZStack {
        _AetronPalette.background

        RadialGradient(
          colors: [
            _AetronPalette.brandAccent.opacity(0.13),
            _AetronPalette.surface.opacity(0.42),
            Color.clear
          ],
          center: .topLeading,
          startRadius: 0,
          endRadius: 210
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [
              _AetronPalette.glassBorder.opacity(0.30),
              Color.white.opacity(0.08),
              _AetronPalette.brandAccent.opacity(0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1.0
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}

// MARK: - Unified AETRON Startup Brand Badge (Exact Vector Mark + Dual-Tone Wordmark)
private struct _AetronLiveBrandBadge: View {
  var body: some View {
    HStack(spacing: 5) {
      _AetronVectorMark(size: 16, color: _AetronPalette.brandAccent)

      VStack(alignment: .leading, spacing: 1.5) {
        HStack(spacing: 0) {
          Text("AE")
            .foregroundStyle(_AetronPalette.brandAccent)
          Text("TRON")
            .foregroundStyle(_AetronPalette.frostInk)
        }
        .font(.system(size: 10, weight: .black, design: .default).italic())
        .tracking(0.8)

        Capsule()
          .fill(
            LinearGradient(
              colors: [
                _AetronPalette.brandAccent,
                _AetronPalette.brandAccent.opacity(0.45),
                Color.clear
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: 40, height: 1.2)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(
      _AetronPalette.surface.opacity(0.75),
      in: Capsule()
    )
    .overlay(
      Capsule()
        .stroke(_AetronPalette.glassBorder.opacity(0.22), lineWidth: 0.8)
    )
  }
}

// MARK: - Exact Official AETRON 02B ("E liền nét") Vector Mark Shape
private struct _AetronVectorMark: View {
  var size: CGFloat = 16
  var color: Color = _AetronPalette.brandAccent

  var body: some View {
    let height = size * (866.06742 / 1215.9102)
    _AetronBrandMarkShape()
      .fill(color, style: FillStyle(eoFill: true))
      .frame(width: size, height: height)
  }
}

private struct _AetronBrandMarkShape: Shape {
  func path(in rect: CGRect) -> Path {
    let minX: CGFloat = -52.87649
    let minY: CGFloat = 208.96629
    let markW: CGFloat = 1215.9102
    let markH: CGFloat = 866.06742

    let scale = min(rect.width / markW, rect.height / markH)
    let dx = (rect.width - markW * scale) / 2 - minX * scale + rect.minX
    let dy = (rect.height - markH * scale) / 2 - minY * scale + rect.minY

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: x * scale + dx, y: y * scale + dy)
    }

    var path = Path()
    // Primary wing + 3-bar continuous "E liền nét"
    path.move(to: pt(697, 254))
    path.addLine(to: pt(804, 431))
    path.addLine(to: pt(408, 1030))
    path.addLine(to: pt(163, 1030))
    path.addLine(to: pt(264.15722, 883))
    path.addLine(to: pt(-7.84278, 883))
    path.addLine(to: pt(25.95103, 815))
    path.addLine(to: pt(310.95103, 815))
    path.addLine(to: pt(357.74485, 747))
    path.addLine(to: pt(161.74485, 747))
    path.addLine(to: pt(195.53866, 679))
    path.addLine(to: pt(404.53866, 679))
    path.addLine(to: pt(451.33247, 611))
    path.addLine(to: pt(187.33247, 611))
    path.addLine(to: pt(221.12629, 543))
    path.addLine(to: pt(498.12629, 543))
    path.closeSubpath()

    // Secondary right wing + crossbar
    path.move(to: pt(820, 458))
    path.addLine(to: pt(1118, 1030))
    path.addLine(to: pt(885, 1030))
    path.addLine(to: pt(843, 946))
    path.addLine(to: pt(685, 946))
    path.addLine(to: pt(566, 832))
    path.addLine(to: pt(785, 832))
    path.addLine(to: pt(684, 638))
    path.closeSubpath()

    return path
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
          .font(.system(size: 8.5, weight: .bold, design: .rounded))
          .foregroundStyle(_AetronPalette.mutedInk)
          .tracking(0.4)
          .lineLimit(1)
      }

      Text(value)
        .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
        .foregroundStyle(_AetronPalette.frostInk)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      _AetronPalette.surface.opacity(0.72),
      in: RoundedRectangle(cornerRadius: 13, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .stroke(_AetronPalette.glassBorder.opacity(0.16), lineWidth: 0.8)
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
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
          .foregroundStyle(_AetronPalette.mutedInk)
          .lineLimit(1)
      }
      Text(value)
        .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
        .foregroundStyle(_AetronPalette.frostInk)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(
      _AetronPalette.surface.opacity(0.75),
      in: RoundedRectangle(cornerRadius: 9, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(_AetronPalette.glassBorder.opacity(0.16), lineWidth: 0.7)
    )
  }
}

// MARK: - Helpers
private func _isVietnamese(_ code: String) -> Bool {
  code.lowercased().hasPrefix("vi")
}

private func _isCycling(_ activityType: String) -> Bool {
  let lower = activityType.lowercased()
  return lower == "cycling" || lower == "bike"
}

private func _activitySymbol(_ activityType: String) -> String {
  switch activityType.lowercased() {
  case "cycling", "bike":
    return "bicycle"
  case "walking", "walk":
    return "figure.walk"
  default:
    return "figure.run"
  }
}

private func _activityTitle(_ activityType: String, isVi: Bool) -> String {
  switch activityType.lowercased() {
  case "cycling", "bike":
    return isVi ? "Đạp xe" : "Cycling"
  case "walking", "walk":
    return isVi ? "Đi bộ" : "Walking"
  case "running", "run":
    return isVi ? "Chạy bộ" : "Running"
  default:
    return isVi ? "Tập luyện" : "Workout"
  }
}

private func _statusTitle(_ status: String, isVi: Bool) -> String {
  switch status.lowercased() {
  case "paused":
    return isVi ? "Tạm dừng" : "Paused"
  case "ended":
    return isVi ? "Hoàn thành" : "Finished"
  default:
    return isVi ? "Đang tập" : "Recording"
  }
}

private func _statusColor(_ status: String) -> Color {
  switch status.lowercased() {
  case "paused":
    return _AetronPalette.pausedAmber
  case "ended":
    return _AetronPalette.brandAccent
  default:
    return _AetronPalette.activeEmerald
  }
}

private func _durationText(_ seconds: Int) -> String {
  let clamped = max(0, seconds)
  let hours = clamped / 3600
  let minutes = (clamped % 3600) / 60
  let remainingSeconds = clamped % 60
  if hours > 0 {
    return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
  }
  return String(format: "%02d:%02d", minutes, remainingSeconds)
}

private func _distanceNumberOnly(_ meters: Double, useMetric: Bool) -> String {
  let km = max(0, meters) / 1000.0
  let display = useMetric ? km : km * 0.621371
  return String(format: "%.2f", display)
}

private func _distanceText(_ meters: Double, useMetric: Bool) -> String {
  let km = max(0, meters) / 1000.0
  let display = useMetric ? km : km * 0.621371
  return String(format: "%.2f %@", display, useMetric ? "km" : "mi")
}

private func _distanceCompactText(_ meters: Double, useMetric: Bool) -> String {
  let km = max(0, meters) / 1000.0
  let display = useMetric ? km : km * 0.621371
  return String(format: "%.1f %@", display, useMetric ? "km" : "mi")
}

private func _speedText(_ kmh: Double, useMetric: Bool) -> String {
  let display = useMetric ? max(0, kmh) : max(0, kmh) * 0.621371
  return String(format: "%.1f %@", display, useMetric ? "km/h" : "mph")
}

private func _paceText(_ kmh: Double, useMetric: Bool) -> String {
  let effectiveSpeed = useMetric ? kmh : kmh * 0.621371
  if effectiveSpeed <= 0.05 {
    return "--"
  }
  let totalSeconds = Int((3600.0 / effectiveSpeed).rounded())
  let minutes = totalSeconds / 60
  let seconds = totalSeconds % 60
  return String(format: "%d'%02d\"", minutes, seconds)
}
