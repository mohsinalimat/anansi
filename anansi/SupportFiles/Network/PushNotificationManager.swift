//
//  PushNotificationManager.swift
//  anansi
//
//  Created by João Nuno Gaspar Apura on 02/05/2019.
//  Copyright © 2019 João Apura. All rights reserved.
//

import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

class PushNotificationManager: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    // Singleton
    static let shared = PushNotificationManager()
    
    func registerForPushNotifications(onSuccess: @escaping () -> Void) {
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (isGranted, err) in
            if err != nil {
                print(err.debugDescription)
                
            } else {
                UNUserNotificationCenter.current().delegate = self
                Messaging.messaging().delegate = self
                
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                onSuccess()
            }
        }
    }
    
    // Updates Firestore push token
    func updateFirestorePushTokenIfNeeded() {
        
        if let token = Messaging.messaging().fcmToken {
            let myID = NetworkManager.shared.getUID()
            NetworkManager.shared.register(value: token, for: "tokenID", in: myID!)
        }
    }
    
    // Boolean whether the user has seen a notification request
    func hasSeenPushNotificationRequest() -> Bool {
        
        var hasSeen = false
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            
            if settings.authorizationStatus != .notDetermined {
                hasSeen = true
            }
        }
        
        return hasSeen
    }
    
    // Boolean whether the user has authorized for notifications
    func isRegisteredForNotifications() -> Bool {
        
        var isRegistered = false
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
            
            switch settings.authorizationStatus {
                
            case .notDetermined:
                // Authorization request has not been made yet
                isRegistered = false
                
            case .denied:
                // User has denied authorization
                isRegistered = false

            case .authorized:
                // User has given authorization.
                isRegistered = true
                
            case .provisional:
                // User has given authorization for non-interruptive notifications
                isRegistered = true
            }
        })
        
        return isRegistered
    }
    
    // Messaging
    
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        
        print(remoteMessage.appData)
    }
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        
        updateFirestorePushTokenIfNeeded()
    }
    
    // User notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print(response)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        //UIApplication.shared.applicationIconBadgeNumber += 1
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TEDxULisboa"), object: nil)
    }
}

