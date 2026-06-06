import CoreLocation
import SwiftUI

@main
struct BeastLocatorWatchApp: App {
  var body: some Scene {
    WindowGroup {
      WatchLocatorView()
    }
  }
}

struct WatchLocatorView: View {
  @StateObject private var model = WatchLocatorModel()

  var body: some View {
    VStack(spacing: 8) {
      Image("Yjsnpi")
        .resizable()
        .scaledToFit()
        .frame(width: 92, height: 92)
        .rotationEffect(.degrees(model.rotationDegrees))
        .animation(.linear(duration: 0.16), value: model.rotationDegrees)

      Text(model.distanceText)
        .font(.system(size: 23, weight: .bold, design: .monospaced))
        .minimumScaleFactor(0.55)
        .lineLimit(1)

      Text(model.directionText)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .onAppear { model.start() }
  }
}

final class WatchLocatorModel: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var rotationDegrees: Double = 0
  @Published var distanceText: String = "取得中..."
  @Published var directionText: String = "方角: --"

  private let manager = CLLocationManager()
  private let destination = CLLocationCoordinate2D(latitude: 35.665554, longitude: 139.669717)
  private var heading: Double = 0
  private var didConfigure = false
  private var hasRotationSample = false

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
    if distanceText == "取得中..." {
      distanceText = "取得失敗"
      directionText = "位置情報を取得できません"
    }
  }

  private func startSensors() {
    distanceText = "取得中..."
    directionText = "方角: --"
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
    update(coordinate)
  }

  private func update(_ current: CLLocationCoordinate2D) {
    let distance = distanceMeters(from: current, to: destination)
    let bearing = bearingDegrees(from: current, to: destination)
    updateRotation(to: bearing - heading - 45)
    distanceText = formatDistance(distance)
    directionText = "方角: \(cardinal(from: normalize360(bearing - heading)))"
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
}
