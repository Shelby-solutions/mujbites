import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase first
    FirebaseApp.configure()
    print("Firebase configured")
    
    // Set messaging delegate
    Messaging.messaging().delegate = self
    print("Messaging delegate set")
    
    if #available(iOS 10.0, *) {
      // Set notification delegate
      UNUserNotificationCenter.current().delegate = self
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional, .criticalAlert]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          print("Notification authorization granted: \(granted)")
          if let error = error {
            print("Notification authorization error: \(error.localizedDescription)")
          }
          
          DispatchQueue.main.async {
            // Register for remote notifications after authorization
            application.registerForRemoteNotifications()
            print("Registered for remote notifications")
            
            // Get current settings to verify configuration
            UNUserNotificationCenter.current().getNotificationSettings { settings in
              print("Notification settings:")
              print("- Authorization status: \(settings.authorizationStatus.rawValue)")
              print("- Alert setting: \(settings.alertSetting.rawValue)")
              print("- Sound setting: \(settings.soundSetting.rawValue)")
              print("- Badge setting: \(settings.badgeSetting.rawValue)")
              print("- Critical Alert setting: \(settings.criticalAlertSetting.rawValue)")
            }
          }
        }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
      application.registerForRemoteNotifications()
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle remote notification registration
  override func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("Received APNS token")
    
    // Set APNS token first
    Messaging.messaging().apnsToken = deviceToken
    
    // Convert token to string for logging
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("APNS token: \(token)")
    
    // Request FCM token after APNS token is set
    Messaging.messaging().token { token, error in
      if let error = error {
        print("Error fetching FCM token: \(error.localizedDescription)")
      }
      if let token = token {
        print("FCM token successfully retrieved: \(token)")
      }
    }
    
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
    print("Error code: \(error._code)")
    print("Error domain: \(error._domain)")
    
    // Check if the error is due to simulator
    if error._domain == "NSCocoaErrorDomain" && error._code == 3010 {
      print("Running on simulator - remote notifications not available")
    }
    
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
    
    // Notify app of token refresh
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}