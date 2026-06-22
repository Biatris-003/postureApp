import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let localNotificationChannelName = "smart_posture_app/local_notifications"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    UNUserNotificationCenter.current().delegate = self
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: localNotificationChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "showNotification":
          guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: nil, details: nil))
            return
          }

          let id = arguments["id"] as? Int ?? Int(Date().timeIntervalSince1970)
          let title = arguments["title"] as? String ?? "Posture Alert"
          let message = arguments["message"] as? String ?? ""
          self?.showLocalNotification(id: id, title: title, message: message)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func showLocalNotification(id: Int, title: String, message: String) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else { return }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = message
      content.sound = .default

      let request = UNNotificationRequest(
        identifier: "posture_alert_\(id)",
        content: content,
        trigger: nil
      )

      UNUserNotificationCenter.current().add(request)
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }
}
