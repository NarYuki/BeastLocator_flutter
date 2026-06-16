import CoreLocation
import SwiftUI
import AVFoundation

@main
struct BeastLocatorWatchApp: App {
  var body: some Scene {
    WindowGroup {
      WatchLocatorView()
    }
    .persistentSystemOverlays(.hidden)
  }
}

struct WatchLocatorView: View {
  @StateObject private var model = WatchLocatorModel()
  @State private var isSettingsPresented = false

  var body: some View {
    GeometryReader { geometry in
      let imageSize = min(max(geometry.size.width * 0.52, 90), 108)
      let edgePadding: CGFloat = 10
      let topPadding = max(geometry.safeAreaInsets.top + 14, edgePadding + 8)
      let topBarY = topPadding + 8

      ZStack(alignment: .top) {
        VStack(spacing: 6) {
          Spacer(minLength: 0)

          Image("Yjsnpi")
            .resizable()
            .scaledToFit()
            .frame(width: imageSize, height: imageSize)
            .rotationEffect(.degrees(model.rotationDegrees))
            .animation(.linear(duration: 0.16), value: model.rotationDegrees)
            .onTapGesture {
              isSettingsPresented = true
            }

          Text(model.distanceText)
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .minimumScaleFactor(0.55)
            .lineLimit(1)

          Text(model.directionText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)

          Spacer(minLength: 0)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .padding(.top, topBarY + 12)
        .padding(.bottom, 4)
        .padding(.horizontal, 6)

        VStack(spacing: 0) {
          WatchClockView()
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, edgePadding)
            .padding(.top, topBarY - 7)

          Spacer(minLength: 0)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .allowsHitTesting(false)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .ignoresSafeArea(.container, edges: .top)
    .onAppear { model.start() }
    .sheet(isPresented: $isSettingsPresented) {
      WatchSettingsView()
    }
    ._statusBarHidden(true)
    .hidePersistentSystemOverlays()
  }
}

private struct WatchClockView: View {
  var body: some View {
    TimelineView(.periodic(from: Date(), by: 30)) { context in
      Text(context.date, format: .dateTime.hour().minute())
        .monospacedDigit()
    }
  }
}

private struct WatchSettingsView: View {
  @AppStorage("arrival_sound_enabled") private var arrivalSoundEnabled = false
  @AppStorage("distance_114514_sound_enabled") private var distance114514SoundEnabled = false
  @AppStorage("distance_interval_sound_enabled") private var distanceIntervalSoundEnabled = false
  @State private var previewPlayer: AVAudioPlayer?

  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle("到着時のこ↑こ↓サウンド", isOn: $arrivalSoundEnabled)
          Button("テスト再生") {
            previewSound(named: "arrival_0km", extension: "wav")
          }
          Toggle("114.514kmで呼び込み先輩を再生", isOn: $distance114514SoundEnabled)
          Button("テスト再生") {
            previewSound(named: "distance_114514km")
          }
          Toggle("1km進むごとに咆哮を再生", isOn: $distanceIntervalSoundEnabled)
          Button("テスト再生") {
            previewSound(named: "distance_interval_kankaku")
          }
        } footer: {
          Text("公共の場で鳴らないよう注意してください")
        }
      }
      .navigationTitle("設定")
    }
  }

  private func previewSound(named name: String, extension ext: String = "mp3") {
    guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
      return
    }
    do {
      try configureWatchPlaybackSession()
      let player = try AVAudioPlayer(contentsOf: url)
      previewPlayer?.stop()
      player.volume = 1.0
      player.prepareToPlay()
      player.play()
      previewPlayer = player
    } catch {
      previewPlayer = nil
    }
  }
}

private extension View {
  @ViewBuilder
  func hidePersistentSystemOverlays() -> some View {
    if #available(watchOS 9.0, *) {
      self.persistentSystemOverlays(.hidden)
    } else {
      self
    }
  }
}

final class WatchLocatorModel: NSObject, ObservableObject, CLLocationManagerDelegate {
  private static let arrivalThresholdMeters = 50.0
  private static let distance114514Meters = 114_514.0
  private static let distance114514ToleranceMeters = 80.0
  private static let distanceIntervalMeters = 1_000.0

  @Published var rotationDegrees: Double = 0
  @Published var distanceText: String = "取得中..."
  @Published var directionText: String = "方角: --"

  private let manager = CLLocationManager()
  private let destination = CLLocationCoordinate2D(latitude: 35.665554, longitude: 139.669717)
  private var heading: Double = 0
  private var didConfigure = false
  private var hasRotationSample = false
  private var previousSoundDistanceMeters: Double?
  private var lastIntervalSoundBucket: Int?
  private var arrivalSoundPlayed = false
  private var distance114514SoundPlayed = false
  private var soundPlayer: AVAudioPlayer?
  private var soundPriority = 0
  private var hasLocationSample = false

  func start() {
    if didConfigure { return }
    didConfigure = true
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 1

    switch manager.authorizationStatus {
    case .notDetermined:
      distanceText = "許可待ち"
      directionText = "位置情報を許可してください"
      manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse:
      startSensors()
    case .denied, .restricted:
      distanceText = "権限なし"
      directionText = "設定で位置情報を許可してください"
    @unknown default:
      distanceText = "権限なし"
      directionText = "設定で位置情報を確認してください"
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      startSensors()
    case .denied, .restricted:
      distanceText = "権限なし"
      directionText = "設定で位置情報を許可してください"
    case .notDetermined:
      distanceText = "許可待ち"
      directionText = "位置情報を許可してください"
    @unknown default:
      distanceText = "権限なし"
      directionText = "設定で位置情報を確認してください"
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let locationError = error as? CLError {
      switch locationError.code {
      case .denied:
        distanceText = "権限なし"
        directionText = "設定で位置情報を許可してください"
      case .locationUnknown, .network:
        if !hasLocationSample {
          distanceText = "取得中..."
          directionText = "位置情報を取得中..."
        }
      default:
        if hasLocationSample {
          directionText = "位置情報の更新待ち"
        } else {
          distanceText = "取得中..."
          directionText = "位置情報を取得中..."
        }
      }
      return
    }

    if hasLocationSample {
      directionText = "位置情報の更新待ち"
    } else {
      distanceText = "取得中..."
      directionText = "位置情報を取得中..."
    }
  }

  private func startSensors() {
    distanceText = "取得中..."
    directionText = "位置情報を取得中..."
    manager.startUpdatingLocation()
    if CLLocationManager.headingAvailable() {
      manager.headingFilter = 1
      manager.startUpdatingHeading()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    heading = normalize360(value)
    if let location = manager.location {
      update(location.coordinate)
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let coordinate = locations.last?.coordinate else { return }
    hasLocationSample = true
    update(coordinate)
  }

  private func update(_ current: CLLocationCoordinate2D) {
    let distance = distanceMeters(from: current, to: destination)
    let bearing = bearingDegrees(from: current, to: destination)
    updateRotation(to: bearing - heading - 45)
    distanceText = formatDistance(distance)
    directionText = "方角: \(cardinal(from: bearing))"
    handleSoundTriggers(distance)
  }

  private func updateRotation(to targetDegrees: Double) {
    let target = normalize360(targetDegrees)
    if !hasRotationSample {
      rotationDegrees = target
      hasRotationSample = true
      return
    }

    var delta = target - normalize360(rotationDegrees)
    if delta > 180 { delta -= 360 }
    if delta < -180 { delta += 360 }
    if abs(delta) < 0.5 { delta = 0 }
    rotationDegrees += delta
  }

  private func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    CLLocation(latitude: from.latitude, longitude: from.longitude)
      .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
  }

  private func bearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let lat1 = radians(from.latitude)
    let lat2 = radians(to.latitude)
    let dLon = radians(to.longitude - from.longitude)
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    return normalize360(degrees(atan2(y, x)))
  }

  private func formatDistance(_ meters: Double) -> String {
    if meters >= 1000 {
      if abs(meters - Self.distance114514Meters) < 0.5 {
        return String(format: "%.3f km", meters / 1000)
      }
      return String(format: "%.2f km", meters / 1000)
    }
    return "\(Int(meters)) m"
  }

  private func cardinal(from bearing: Double) -> String {
    let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let index = Int(((bearing + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
    return dirs[index]
  }

  private func normalize360(_ value: Double) -> Double {
    let mod = value.truncatingRemainder(dividingBy: 360)
    return mod < 0 ? mod + 360 : mod
  }

  private func radians(_ value: Double) -> Double {
    value * .pi / 180
  }

  private func degrees(_ value: Double) -> Double {
    value * 180 / .pi
  }

  private func handleSoundTriggers(_ distanceMeters: Double) {
    guard distanceMeters.isFinite else { return }

    let defaults = UserDefaults.standard
    let previous = previousSoundDistanceMeters
    let enteredArrivalRange =
      distanceMeters <= Self.arrivalThresholdMeters &&
      (previous == nil || previous! > Self.arrivalThresholdMeters)

    if distanceMeters > Self.arrivalThresholdMeters + 25 {
      arrivalSoundPlayed = false
    } else if defaults.bool(forKey: "arrival_sound_enabled") &&
      !arrivalSoundPlayed &&
      enteredArrivalRange {
      arrivalSoundPlayed = true
      playSound(named: "arrival_0km", extension: "wav", priority: 4)
    }

    let upper114514 = Self.distance114514Meters + Self.distance114514ToleranceMeters
    let lower114514 = Self.distance114514Meters - Self.distance114514ToleranceMeters
    let isInside114514Range = distanceMeters >= lower114514 && distanceMeters <= upper114514
    let crossed114514Range = previous != nil && previous! > upper114514 && distanceMeters < lower114514

    if !defaults.bool(forKey: "distance_114514_sound_enabled") {
      distance114514SoundPlayed = false
    } else if !distance114514SoundPlayed && (isInside114514Range || crossed114514Range) {
      distance114514SoundPlayed = true
      playSound(named: "distance_114514km", extension: "mp3", priority: 3)
    } else if distanceMeters > upper114514 + 500 {
      distance114514SoundPlayed = false
    }

    if defaults.bool(forKey: "distance_interval_sound_enabled") {
      let currentBucket = Int((distanceMeters / Self.distanceIntervalMeters).rounded(.down))
      if let previousBucket = lastIntervalSoundBucket, currentBucket < previousBucket {
        playSound(named: "distance_interval_kankaku", extension: "mp3", priority: 1)
      }
      lastIntervalSoundBucket = currentBucket
    } else {
      lastIntervalSoundBucket = nil
    }

    previousSoundDistanceMeters = distanceMeters
  }

  private func playSound(named name: String, extension ext: String, priority: Int) {
    if let player = soundPlayer, player.isPlaying, priority <= soundPriority {
      return
    }
    guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
      return
    }

    do {
      try configureWatchPlaybackSession()
      let player = try AVAudioPlayer(contentsOf: url)
      soundPlayer?.stop()
      player.volume = 1.0
      player.prepareToPlay()
      guard player.play() else { return }
      soundPlayer = player
      soundPriority = priority
    } catch {
      soundPlayer = nil
      soundPriority = 0
    }
  }
}

private func configureWatchPlaybackSession() throws {
  let session = AVAudioSession.sharedInstance()
  try session.setCategory(.playback, mode: .default, policy: .default)
  try session.setActive(true)
}
