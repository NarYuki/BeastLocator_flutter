import ActivityKit
import SwiftUI
import WidgetKit

struct BeastNativeActivityAttributes: ActivityAttributes, Identifiable {
  public struct ContentState: Codable, Hashable {
    var distance: String
    var direction: String
    var rotation: Double
    var progress: Int
    var arrived: Bool
    var shout: Bool
    var sequence: Int
  }

  var id = UUID()
  var customId: String
}

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var appGroupId: String
  }

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

private let sharedDefaults = UserDefaults(suiteName: "group.moe.n4tsu.beast")!
private let standardDefaults = UserDefaults.standard

private let defaultDestinationLat = 35.665554
private let defaultDestinationLng = 139.669717
private let arrowImageForwardOffsetDegrees = 45.0

private struct BeastHomeWidgetEntry: TimelineEntry {
  let date: Date
  let title: String
  let distance: String
  let rotation: Double
  let arrived: Bool
}

private struct BeastHomeWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> BeastHomeWidgetEntry {
    BeastHomeWidgetEntry(
      date: Date(),
      title: "位置情報待機中",
      distance: "--",
      rotation: 0,
      arrived: false
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (BeastHomeWidgetEntry) -> Void) {
    completion(makeEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BeastHomeWidgetEntry>) -> Void) {
    let entry = makeEntry()
    completion(Timeline(
      entries: [entry],
      policy: .after(Date().addingTimeInterval(60))
    ))
  }

  private func makeEntry() -> BeastHomeWidgetEntry {
    guard sharedDefaults.bool(forKey: "widget_has_data") else {
      return BeastHomeWidgetEntry(
        date: Date(),
        title: "位置情報待機中",
        distance: "--",
        rotation: 0,
        arrived: false
      )
    }

    let arrived = sharedDefaults.bool(forKey: "widget_arrived")
    let distance = sharedDefaults.string(forKey: "widget_distance") ?? "--"
    let title = sharedDefaults.string(forKey: "widget_direction") ?? "方角: --"
    let rotation = finiteDouble(forKey: "widget_rotation") ?? 0

    return BeastHomeWidgetEntry(
      date: Date(),
      title: title,
      distance: distance,
      rotation: rotation,
      arrived: arrived
    )
  }

  private func finiteDouble(forKey key: String) -> Double? {
    let rawValue = sharedDefaults.object(forKey: key) ?? standardDefaults.object(forKey: key)
    if let value = rawValue as? NSNumber {
      let doubleValue = value.doubleValue
      return doubleValue.isFinite ? doubleValue : nil
    }
    if let value = rawValue as? Double, value.isFinite {
      return value
    }
    if let value = rawValue as? String, let doubleValue = Double(value), doubleValue.isFinite {
      return doubleValue
    }
    return nil
  }
}

@available(iOSApplicationExtension 16.1, *)
struct BeastLocatorHomeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "BeastLocatorHomeWidget", provider: BeastHomeWidgetProvider()) { entry in
      BeastHomeWidgetView(entry: entry)
    }
    .configurationDisplayName("BeastLocator")
    .description("野獣邸までの距離と方角を表示します。")
    .supportedFamilies([.systemSmall, .accessoryRectangular])
  }
}

private struct BeastHomeWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: BeastHomeWidgetEntry

  var body: some View {
    switch family {
    case .accessoryRectangular:
      accessoryRectangularBody
    default:
      systemSmallBody
    }
  }

  private var systemSmallBody: some View {
    ZStack {
      Color(red: 0.965, green: 0.980, blue: 1.0)
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 10) {
          if entry.arrived {
            Text("🎉")
              .font(.system(size: 42))
              .frame(width: 58, height: 58, alignment: .center)
          } else {
            Image("Yjsnpi")
              .resizable()
              .scaledToFit()
              .frame(width: 60, height: 60)
              .rotationEffect(.degrees(entry.rotation))
          }
          Text(entry.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 0.200, green: 0.255, blue: 0.333))
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        Spacer(minLength: 4)
        Text(entry.distance)
          .font(.system(size: 34, weight: .bold, design: .monospaced))
          .foregroundStyle(Color(red: 0.059, green: 0.090, blue: 0.165))
          .lineLimit(1)
          .minimumScaleFactor(0.45)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(4)
    }
    .beastWidgetBackground()
  }

  private var accessoryRectangularBody: some View {
    HStack(spacing: 8) {
      if entry.arrived {
        Text("🎉")
          .font(.system(size: 24))
          .frame(width: 32, height: 32)
      } else {
        Image("Yjsnpi")
          .resizable()
          .scaledToFit()
          .frame(width: 32, height: 32)
          .rotationEffect(.degrees(entry.rotation))
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(entry.arrived ? "こ↑こ↓" : "BeastLocator")
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
        Text("\(entry.distance)  \(entry.title)")
          .font(.system(.caption2, design: .monospaced).weight(.bold))
          .lineLimit(1)
          .minimumScaleFactor(0.65)
      }
      Spacer(minLength: 0)
    }
  }
}

private extension View {
  @ViewBuilder
  func beastWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) {
        Color(red: 0.965, green: 0.980, blue: 1.0)
      }
    } else {
      background(Color(red: 0.965, green: 0.980, blue: 1.0))
    }
  }
}

private struct BeastState {
  let distance: String
  let direction: String
  let rotation: Double
  let progress: Int
  let arrived: Bool
  let shout: Bool

  init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
    let key: (String) -> String = { context.attributes.prefixedKey($0) }
    distance = sharedDefaults.string(forKey: key("distance")) ?? "--"
    direction = sharedDefaults.string(forKey: key("direction")) ?? "--"
    rotation = sharedDefaults.double(forKey: key("rotation"))
    progress = sharedDefaults.integer(forKey: key("progress"))
    arrived = sharedDefaults.bool(forKey: key("arrived"))
    shout = sharedDefaults.bool(forKey: key("shout"))
  }
}

@available(iOSApplicationExtension 16.1, *)
struct BeastLocatorLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      LiveActivityLockScreenView(state: BeastState(context: context))
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(Color.white)
    } dynamicIsland: { context in
      let state = BeastState(context: context)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image("Yjsnpi")
            .resizable()
            .scaledToFit()
            .frame(width: 42, height: 42)
            .rotationEffect(.degrees(state.arrived ? 0 : state.rotation))
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(state.shout ? "ンアッー!" : (state.arrived ? "こ↑こ↓" : "BeastLocator"))
              .font(.headline)
              .foregroundStyle(.white)
            if !state.shout {
              Text(state.direction)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            }
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(state.shout ? "ンアッー!" : state.distance)
            .font(.system(.title3, design: .monospaced).weight(.bold))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.7)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if !state.shout {
            ProgressView(value: Double(state.progress), total: 100)
              .tint(.yellow)
          }
        }
      } compactLeading: {
        Image("Yjsnpi")
          .resizable()
          .scaledToFit()
          .frame(width: 22, height: 22)
          .rotationEffect(.degrees(state.arrived ? 0 : state.rotation))
      } compactTrailing: {
        Text(state.shout ? "ンアッー!" : state.distance)
          .font(.caption2.monospacedDigit().weight(.bold))
          .foregroundStyle(.white)
      } minimal: {
        Image("Yjsnpi")
          .resizable()
          .scaledToFit()
          .rotationEffect(.degrees(state.arrived ? 0 : state.rotation))
      }
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
struct BeastNativeLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BeastNativeActivityAttributes.self) { context in
      LiveActivityLockScreenView(state: BeastLiveDisplayState(context.state))
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(Color.white)
    } dynamicIsland: { context in
      let state = BeastLiveDisplayState(context.state)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          BeastImage(rotation: state.rotation, arrived: state.arrived, size: 42)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(state.shout ? "ンアッー!" : (state.arrived ? "こ↑こ↓" : "BeastLocator"))
              .font(.headline)
              .foregroundStyle(.white)
            if !state.shout {
              Text(state.direction)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            }
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(state.shout ? "ンアッー!" : state.distance)
            .font(.system(.title3, design: .monospaced).weight(.bold))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.7)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if !state.shout {
            ProgressView(value: Double(state.progress), total: 100)
              .tint(.yellow)
          }
        }
      } compactLeading: {
        BeastImage(rotation: state.rotation, arrived: state.arrived, size: 22)
      } compactTrailing: {
        Text(state.shout ? "ンアッー!" : state.distance)
          .font(.caption2.monospacedDigit().weight(.bold))
          .foregroundStyle(.white)
      } minimal: {
        BeastImage(rotation: state.rotation, arrived: state.arrived, size: nil)
      }
    }
  }
}

private struct BeastLiveDisplayState {
  let distance: String
  let direction: String
  let rotation: Double
  let progress: Int
  let arrived: Bool
  let shout: Bool

  init(_ state: BeastNativeActivityAttributes.ContentState) {
    distance = state.distance
    direction = state.direction
    rotation = state.rotation
    progress = state.progress
    arrived = state.arrived
    shout = state.shout
  }

  init(_ state: BeastState) {
    distance = state.distance
    direction = state.direction
    rotation = state.rotation
    progress = state.progress
    arrived = state.arrived
    shout = state.shout
  }
}

private struct BeastImage: View {
  let rotation: Double
  let arrived: Bool
  let size: CGFloat?

  var body: some View {
    let image = Image("Yjsnpi")
      .resizable()
      .scaledToFit()
      .rotationEffect(.degrees(arrived ? 0 : rotation))
      .animation(.linear(duration: 0.55), value: rotation)

    if let size {
      image.frame(width: size, height: size)
    } else {
      image
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct LiveActivityLockScreenView: View {
  let state: BeastLiveDisplayState

  init(state: BeastState) {
    self.state = BeastLiveDisplayState(state)
  }

  init(state: BeastLiveDisplayState) {
    self.state = state
  }

  var body: some View {
    HStack(spacing: 14) {
      BeastImage(rotation: state.rotation, arrived: state.arrived, size: 56)
      VStack(alignment: .leading, spacing: 4) {
        Text(state.shout ? "ンアッー!" : (state.arrived ? "こ↑こ↓" : "目的地へ接近中"))
          .font(.headline)
          .foregroundStyle(.white)
        if !state.shout {
          Text("方角: \(state.direction)")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.72))
          ProgressView(value: Double(state.progress), total: 100)
            .tint(.yellow)
        }
      }
      Spacer()
      Text(state.shout ? "ンアッー!" : state.distance)
        .font(.system(.title3, design: .monospaced).weight(.bold))
        .foregroundStyle(.white)
    }
    .padding()
    .background(Color.black)
  }
}

@main
struct BeastLocatorWidgetBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOSApplicationExtension 16.1, *) {
      BeastLocatorHomeWidget()
    }
    if #available(iOSApplicationExtension 16.1, *) {
      BeastLocatorLiveActivity()
    }
  }
}

private func distance(from source: (lat: Double, lng: Double), to target: (lat: Double, lng: Double)) -> Double {
  let earthRadiusMeters = 6_371_000.0
  let lat1 = degreesToRadians(source.lat)
  let lat2 = degreesToRadians(target.lat)
  let deltaLat = degreesToRadians(target.lat - source.lat)
  let deltaLng = degreesToRadians(target.lng - source.lng)
  let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
    cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2)
  let c = 2 * atan2(sqrt(a), sqrt(1 - a))
  return earthRadiusMeters * c
}

private func bearingDegrees(from source: (lat: Double, lng: Double), to target: (lat: Double, lng: Double)) -> Double {
  let lat1 = degreesToRadians(source.lat)
  let lat2 = degreesToRadians(target.lat)
  let deltaLng = degreesToRadians(target.lng - source.lng)
  let y = sin(deltaLng) * cos(lat2)
  let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLng)
  return normalize360(radiansToDegrees(atan2(y, x)))
}

private func normalize360(_ degrees: Double) -> Double {
  let value = degrees.truncatingRemainder(dividingBy: 360)
  return value < 0 ? value + 360 : value
}

private func cardinal(from bearing: Double) -> String {
  let directions = ["北", "北東", "東", "南東", "南", "南西", "西", "北西"]
  let index = Int(((normalize360(bearing) + 22.5) / 45).rounded(.down)) % directions.count
  return directions[index]
}

private func formatWidgetDistance(_ meters: Double) -> String {
  if meters >= 1000 {
    if abs(meters - 114_514.0) < 0.5 {
      return String(format: "%.3f km", meters / 1000)
    }
    let km = meters / 1000
    if km >= 100 {
      return String(format: "%.0f km", km)
    }
    return String(format: "%.1f km", km)
  }
  return String(format: "%.0f m", meters.rounded())
}

private func degreesToRadians(_ degrees: Double) -> Double {
  degrees * .pi / 180
}

private func radiansToDegrees(_ radians: Double) -> Double {
  radians * 180 / .pi
}
