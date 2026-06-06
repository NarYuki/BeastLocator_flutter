import Flutter
import UIKit
import CoreLocation
import AVFoundation
import ActivityKit
import WidgetKit

@available(iOS 16.1, *)
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

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVAudioPlayerDelegate, CLLocationManagerDelegate {
  private var soundPlayer: AVAudioPlayer?
  private var soundPriority = 0
  private var shouldResumeSoundAfterInterruption = false
  private let locationAuthorizationManager = CLLocationManager()
  private let appGroupId = "group.moe.n4tsu.beast"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "moe.n4tsu.beast/native",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "syncState":
          if let args = call.arguments as? [String: Any] {
            self?.syncSharedState(args)
          }
          result(nil)
        case "requestAlwaysLocationAuthorization":
          self?.requestAlwaysLocationAuthorization()
          result(nil)
        case "updateLiveActivity":
          guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "bad_args", message: "live activity data is required", details: nil))
            return
          }
          self?.updateLiveActivity(data: args, result: result)
        case "endLiveActivity":
          self?.endLiveActivity(result: result)
        case "reverseGeocode":
          guard
            let args = call.arguments as? [String: Any],
            let lat = args["lat"] as? Double,
            let lng = args["lng"] as? Double
          else {
            result(FlutterError(code: "bad_args", message: "lat/lng are required", details: nil))
            return
          }
          self?.reverseGeocode(lat: lat, lng: lng, result: result)
        case "playSound":
          guard
            let args = call.arguments as? [String: Any],
            let asset = args["asset"] as? String,
            let priority = args["priority"] as? Int
          else {
            result(FlutterError(code: "bad_args", message: "asset and priority are required", details: nil))
            return
          }
          result(self?.playSound(asset: asset, priority: priority) ?? false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioSessionInterruption),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance()
    )
    locationAuthorizationManager.delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func playSound(asset: String, priority: Int) -> Bool {
    if let player = soundPlayer, player.isPlaying, priority <= soundPriority {
      return false
    }

    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    guard let assetPath = Bundle.main.path(forResource: assetKey, ofType: nil) else {
      return false
    }

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)

      soundPlayer?.stop()
      let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: assetPath))
      player.delegate = self
      player.prepareToPlay()
      guard player.play() else {
        soundPriority = 0
        return false
      }
      soundPlayer = player
      soundPriority = priority
      return true
    } catch {
      soundPlayer = nil
      soundPriority = 0
      return false
    }
  }

  private func requestAlwaysLocationAuthorization() {
    locationAuthorizationManager.requestAlwaysAuthorization()
  }

  private func syncSharedState(_ values: [String: Any]) {
    guard let defaults = UserDefaults(suiteName: appGroupId) else {
      return
    }

    for (key, value) in values {
      if value is NSNull {
        defaults.removeObject(forKey: key)
      } else {
        defaults.set(value, forKey: key)
      }
    }
    defaults.set(Date().timeIntervalSince1970, forKey: "last_sync_timestamp")
    defaults.synchronize()

    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: "BeastLocatorHomeWidget")
    }
  }

  private func updateLiveActivity(data: [String: Any], result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }

    let activityId = data["activityId"] as? String ?? "beast-locator-navigation"
    let state = BeastNativeActivityAttributes.ContentState(
      distance: data["distance"] as? String ?? "--",
      direction: data["direction"] as? String ?? "--",
      rotation: number(from: data["rotation"]),
      progress: Int(number(from: data["progress"]).rounded()),
      arrived: data["arrived"] as? Bool ?? false,
      shout: data["shout"] as? Bool ?? false,
      sequence: Int(number(from: data["sequence"]).rounded())
    )

    Task {
      let activity = await MainActor.run {
        Activity<BeastNativeActivityAttributes>.activities.first {
          $0.attributes.customId == activityId &&
          $0.activityState != .dismissed &&
          $0.activityState != .ended
        }
      }

      if let activity {
        if #available(iOS 16.2, *) {
          await activity.update(ActivityContent(state: state, staleDate: nil))
        } else {
          await activity.update(using: state)
        }
      } else {
        do {
          let attributes = BeastNativeActivityAttributes(customId: activityId)
          if #available(iOS 16.2, *) {
            _ = try Activity.request(
              attributes: attributes,
              content: ActivityContent(state: state, staleDate: nil),
              pushType: nil
            )
          } else {
            _ = try Activity<BeastNativeActivityAttributes>.request(
              attributes: attributes,
              contentState: state,
              pushType: nil
            )
          }
        } catch {
          await MainActor.run {
            result(FlutterError(
              code: "LIVE_ACTIVITY_ERROR",
              message: "can't update live activity",
              details: error.localizedDescription
            ))
          }
          return
        }
      }

      await MainActor.run { result(nil) }
    }
  }

  private func endLiveActivity(result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }

    Task {
      for activity in Activity<BeastNativeActivityAttributes>.activities {
        await activity.end(dismissalPolicy: .immediate)
      }
      await MainActor.run { result(nil) }
    }
  }

  private func number(from value: Any?) -> Double {
    if let value = value as? Double { return value }
    if let value = value as? Int { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    return 0
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard player === soundPlayer else { return }
    soundPlayer = nil
    soundPriority = 0
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: .notifyOthersOnDeactivation
    )
  }

  @objc private func handleAudioSessionInterruption(_ notification: Notification) {
    guard
      let info = notification.userInfo,
      let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else {
      return
    }

    switch type {
    case .began:
      shouldResumeSoundAfterInterruption = soundPlayer?.isPlaying == true
    case .ended:
      guard shouldResumeSoundAfterInterruption else { return }
      shouldResumeSoundAfterInterruption = false
      try? AVAudioSession.sharedInstance().setActive(true)
      soundPlayer?.play()
    @unknown default:
      break
    }
  }

  private func reverseGeocode(lat: Double, lng: Double, result: @escaping FlutterResult) {
    let location = CLLocation(latitude: lat, longitude: lng)
    CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ja_JP")) { placemarks, error in
      if error != nil {
        result(String(format: "%.6f, %.6f", lat, lng))
        return
      }
      if let placemark = placemarks?.first {
        let parts = [
          placemark.administrativeArea,
          placemark.locality,
          placemark.subLocality,
          placemark.thoroughfare,
          placemark.subThoroughfare
        ].compactMap { $0 }.filter { !$0.isEmpty }
        result(parts.isEmpty ? String(format: "%.6f, %.6f", lat, lng) : parts.joined(separator: " "))
      } else {
        result(String(format: "%.6f, %.6f", lat, lng))
      }
    }
  }

}
