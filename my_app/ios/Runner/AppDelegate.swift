import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase
    FirebaseApp.configure()
    print("Firebase configured")
    
    // Set messaging delegate
    Messaging.messaging().delegate = self
    print("Messaging delegate set")
    
    // Request permission for notifications with provisional authorization
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional, .criticalAlert]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          print("Notification authorization granted: \(granted)")
          if let error = error {
            print("Notification authorization error: \(error.localizedDescription)")
          }
          
          // Get current settings to verify configuration
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings:")
            print("- Authorization status: \(settings.authorizationStatus.rawValue)")
            print("- Alert setting: \(settings.alertSetting.rawValue)")
            print("- Sound setting: \(settings.soundSetting.rawValue)")
            print("- Badge setting: \(settings.badgeSetting.rawValue)")
            print("- Notification Center setting: \(settings.notificationCenterSetting.rawValue)")
            print("- Critical Alert setting: \(settings.criticalAlertSetting.rawValue)")
            print("- Show previews setting: \(settings.showPreviewsSetting.rawValue)")
          }
        }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    // Register for remote notifications
    application.registerForRemoteNotifications()
    print("Registered for remote notifications")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle remote notification registration
  override func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("Received APNS token")
    Messaging.messaging().apnsToken = deviceToken
    
    // Convert token to string for logging
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("APNS token: \(token)")
    
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

  // Handle receiving notification in background
  override func application(_ application: UIApplication,
                          didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                          fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("Received background notification: \(userInfo)")
    
    Messaging.messaging().appDidReceiveMessage(userInfo)
    
    // Handle the notification in background
    if application.applicationState == .background || application.applicationState == .inactive {
      // Schedule a local notification to show in the background
      if #available(iOS 10.0, *) {
        let content = UNMutableNotificationContent()
        content.title = userInfo["title"] as? String ?? "New Order"
        content.body = userInfo["body"] as? String ?? "You have a new order!"
        content.sound = UNNotificationSound.default
        content.userInfo = userInfo
        
        // Add thread identifier for grouping
        content.threadIdentifier = "new_orders"
        
        // Set interruption level for time-sensitive notifications
        if #available(iOS 15.0, *) {
          content.interruptionLevel = .timeSensitive
        }
        
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                          content: content,
                                          trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
          if let error = error {
            print("Error showing background notification: \(error.localizedDescription)")
          }
        }
      }
    }
    
    completionHandler(.newData)
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
  
  // Handle background messages
  func messaging(_ messaging: Messaging,
                didReceive remoteMessage: MessagingDelegate) {
    print("Received background message: \(remoteMessage)")
  }
}
