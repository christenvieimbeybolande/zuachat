import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 🔥 Firebase
    FirebaseApp.configure()

    // 🔔 Notifications (iOS 10+)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // 🔔 FCM delegate
    Messaging.messaging().delegate = self

    // 📲 Enregistrement APNs
    application.registerForRemoteNotifications()

    // 🔌 Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // =========================================================
  // 🔔 FOREGROUND NOTIFICATION (AFFICHER + SON)
  // =========================================================
  @available(iOS 10.0, *)
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .badge, .sound])
  }

  // =========================================================
  // 🔑 TOKEN FCM (LOG OPTIONNEL)
  // =========================================================
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // Tu peux logger si tu veux :
    // print("📲 FCM token iOS:", fcmToken ?? "nil")
  }
}
