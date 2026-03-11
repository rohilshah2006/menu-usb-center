import Foundation
import UserNotifications
import AppKit
import SwiftUI

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    // User Default mapping for internal checks
    @AppStorage("MenuUSBCenter_ShowNotifications") var notificationsEnabled: Bool = true
    
    private let center = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        center.delegate = self
        requestAuthorization()
    }
    
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func sendDeviceConnectedNotification(device: USBDevice) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "USB Device Connected"
        content.subtitle = device.displayName
        content.body = "A new device was plugged in."
        
        content.sound = nil // We handle our own sounds via SoundManager
        
        // Use a standard generic identifier so macOS groups them automatically
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
    
    func sendDeviceDisconnectedNotification(device: USBDevice) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "USB Device Disconnected"
        content.subtitle = device.displayName
        content.body = "The device was safely removed."
        content.sound = nil
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
    
    // Ensure notifications show even when app is active (which it always is, as a menu bar app)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
