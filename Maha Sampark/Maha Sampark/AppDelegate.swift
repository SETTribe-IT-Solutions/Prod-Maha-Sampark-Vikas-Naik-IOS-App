//
//  AppDelegate.swift
//  Maha Sampark
//
//  Created by SETTribe on 25/03/25.
//

import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Set Firebase Messaging delegate
        Messaging.messaging().delegate = self
        
        // Set User Notification Center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register for Remote Notifications
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // MARK: - APNs Device Token Registration
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs Device Token: \(tokenString)")
        
        // Link the APNs token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        // Store APNs Token in UserDefaults for easy access
        UserDefaults.standard.set(tokenString, forKey: "APNsToken")
        
        // Post notification so WebViewCoordinator can receive it
        let dataDict: [String: String] = ["token": tokenString]
        NotificationCenter.default.post(
            name: Notification.Name("APNsTokenUpdated"),
            object: nil,
            userInfo: dataDict
        )
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate (Notification Handling)
    
    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("Notification received in foreground: \(userInfo)")
        
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle tapping/interaction with notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")
        
        // Handle notification deep-link or custom actions if any
        
        completionHandler()
    }
}

// MARK: - Firebase Messaging Delegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase Registration Token (FCM): \(String(describing: fcmToken))")
        guard let fcmToken = fcmToken else { return }
        
        // Store FCM Token in UserDefaults
        UserDefaults.standard.set(fcmToken, forKey: "FCMToken")
        
        // Post notification so WebViewCoordinator can receive it
        let dataDict: [String: String] = ["token": fcmToken]
        NotificationCenter.default.post(
            name: Notification.Name("FCMTokenUpdated"),
            object: nil,
            userInfo: dataDict
        )
    }
}
