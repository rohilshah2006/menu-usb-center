import Foundation
import IOKit
import IOKit.usb
import Cocoa

class USBMonitor {
    static let shared = USBMonitor()
    
    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
    var onDeviceConnected: ((_ vendorId: Int, _ productId: Int, _ serialNumber: String, _ name: String, _ speed: String?, _ vendorName: String?, _ usbVersion: String?, _ deviceClass: Int?, _ parentIdentifier: String?) -> Void)?
    var onDeviceDisconnected: ((_ vendorId: Int, _ productId: Int, _ serialNumber: String) -> Void)?
    
    private init() {
        onDeviceConnected = { vendorId, productId, serialNumber, name, speed, vendorName, usbVersion, deviceClass, parentIdentifier in
            DeviceManager.shared.deviceConnected(vendorId: vendorId, productId: productId, serialNumber: serialNumber, name: name, speed: speed, vendorName: vendorName, usbVersion: usbVersion, deviceClass: deviceClass, parentIdentifier: parentIdentifier)
            SoundManager.shared.playConnectSound()
            
            if let device = DeviceManager.shared.getDevice(vendorId: vendorId, productId: productId, serialNumber: serialNumber) {
                NotificationManager.shared.sendDeviceConnectedNotification(device: device)
            }
        }
        onDeviceDisconnected = { vendorId, productId, serialNumber in
            if let device = DeviceManager.shared.getDevice(vendorId: vendorId, productId: productId, serialNumber: serialNumber) {
                NotificationManager.shared.sendDeviceDisconnectedNotification(device: device)
            }
            
            DeviceManager.shared.deviceDisconnected(vendorId: vendorId, productId: productId, serialNumber: serialNumber)
            SoundManager.shared.playDisconnectSound()
        }
    }
    
    func start() {
        var masterPort: mach_port_t = 0
        IOMasterPort(mach_port_t(MACH_PORT_NULL), &masterPort)
        notificationPort = IONotificationPortCreate(masterPort)
        
        guard let notificationPort = notificationPort else {
            print("Failed to create IONotificationPort")
            return
        }
        
        let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
        
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        
        // Add matching for both attach and detach
        let matchingDictForAdd = NSMutableDictionary(dictionary: matchingDict)
        
        // Set up callback for device added
        // The callback needs to be a C function pointer, so we'll use a globally-available block/closure trick using a wrapper
        
        let pointerToSelf = Unmanaged.passUnretained(self).toOpaque()
        
        let addCallback: IOServiceMatchingCallback = { (userData, iterator) in
            let monitor = Unmanaged<USBMonitor>.fromOpaque(userData!).takeUnretainedValue()
            monitor.deviceAdded(iterator: iterator)
        }
        
        let removeCallback: IOServiceMatchingCallback = { (userData, iterator) in
            let monitor = Unmanaged<USBMonitor>.fromOpaque(userData!).takeUnretainedValue()
            monitor.deviceRemoved(iterator: iterator)
        }
        
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOMatchedNotification,
            matchingDictForAdd,
            addCallback,
            pointerToSelf,
            &addedIterator
        )
        
        // Prime the iterator
        deviceAdded(iterator: addedIterator)
        
        let matchingDictForRemove = NSMutableDictionary(dictionary: matchingDict)
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            matchingDictForRemove,
            removeCallback,
            pointerToSelf,
            &removedIterator
        )
        
        deviceRemoved(iterator: removedIterator)
        
        print("USB Monitor Started")
    }
    
    func stop() {
        if let port = notificationPort {
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
    }
    
    private func deviceAdded(iterator: io_iterator_t) {
        var device: io_object_t = IOIteratorNext(iterator)
        while device != 0 {
            if let properties = getProperties(for: device) {
                let vendorId = properties["idVendor"] as? Int ?? 0
                let productId = properties["idProduct"] as? Int ?? 0
                let serialNumber = properties["USB Serial Number"] as? String ?? "UnknownSerial"
                let name = properties["USB Product Name"] as? String ?? "Unknown Device"
                let rawSpeed = properties["Device Speed"] as? Int ?? -1
                let vendorName = properties["USB Vendor Name"] as? String
                
                let bDeviceClass = properties["bDeviceClass"] as? Int ?? 0
                let bInterfaceClass = properties["bInterfaceClass"] as? Int ?? 0
                let finalClass = (bDeviceClass == 0 && bInterfaceClass != 0) ? bInterfaceClass : bDeviceClass
                let deviceClass = finalClass == 0 ? nil : finalClass
                
                // bcdUSB is often an integer representing hex (e.g., 0x0200 = 512, 0x0300 = 768)
                let bcdUSB = properties["bcdUSB"] as? Int
                var usbVersionString: String? = nil
                if let bcd = bcdUSB {
                    let hexString = String(format: "%04X", bcd)
                    if hexString.hasPrefix("01") { usbVersionString = "USB 1.\(hexString.dropFirst(2).first!)" }
                    else if hexString.hasPrefix("02") { usbVersionString = "USB 2.0" }
                    else if hexString.hasPrefix("03") { 
                        if hexString == "0320" { usbVersionString = "USB 3.2" }
                        else if hexString == "0310" { usbVersionString = "USB 3.1" }
                        else { usbVersionString = "USB 3.0" }
                    }
                    else { usbVersionString = "Unknown (0x\(hexString))" }
                }
                
                let speedString: String?
                switch rawSpeed {
                case 0: speedString = "USB 1.0 Low-speed (1.5 Mbps)"
                case 1: speedString = "USB 1.1 Full-speed (12 Mbps)"
                case 2: speedString = "USB 2.0 High-speed (480 Mbps)"
                case 3: speedString = "USB 3.0 / 3.1 Gen1 / 3.2 Gen1x1 (5 Gbps)"
                case 4: speedString = "USB 3.1 Gen2 / 3.2 Gen2x1 (10 Gbps)"
                default: speedString = nil
                }
                
                // Identify parent topological relationships for Nested Hubs UI
                var parentIdStr: String? = nil
                var parent: io_registry_entry_t = 0
                var current = device
                
                while IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS {
                    var parentClassName = [CChar](repeating: 0, count: 128)
                    IOObjectGetClass(parent, &parentClassName)
                    let parentClassStr = String(cString: parentClassName)
                    
                    // If the parent is a Hub
                    if parentClassStr == "IOUSBHostDevice" || parentClassStr == "IOUSBDevice" {
                        if let parentProps = self.getProperties(for: parent) {
                            if let pVid = parentProps["idVendor"] as? Int,
                               let pPid = parentProps["idProduct"] as? Int {
                                // Locate the parent by its structural UUID. We omit serial since hubs often don't reliably broadcast them
                                // We will match this against connected devices where ID starts with this prefix
                                parentIdStr = "\(pVid)-\(pPid)"
                                break
                            }
                        }
                    }
                    
                    // If the parent is a root controller, we are at the top, stop here
                    if !parentClassStr.contains("USB") {
                        break
                    }
                    
                    if current != device { IOObjectRelease(current) }
                    current = parent
                }
                if current != device { IOObjectRelease(current) }
                if parent != 0 { IOObjectRelease(parent) }
                
                print("Connected: \(name) (\(vendorId):\(productId)) Serial: \(serialNumber) Speed: \(speedString ?? "Unknown") Version: \(usbVersionString ?? "nil") Class: \(deviceClass?.description ?? "nil") Parent: \(parentIdStr ?? "Root")")
                DispatchQueue.main.async {
                    self.onDeviceConnected?(vendorId, productId, serialNumber, name, speedString, vendorName, usbVersionString, deviceClass, parentIdStr)
                }
            }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
    
    private func deviceRemoved(iterator: io_iterator_t) {
        var device: io_object_t = IOIteratorNext(iterator)
        while device != 0 {
            if let properties = getProperties(for: device) {
                let vendorId = properties["idVendor"] as? Int ?? 0
                let productId = properties["idProduct"] as? Int ?? 0
                let serialNumber = properties["USB Serial Number"] as? String ?? "UnknownSerial"
                let name = properties["USB Product Name"] as? String ?? "Unknown Device"

                print("Disconnected: \(name) (\(vendorId):\(productId)) Serial: \(serialNumber)")
                DispatchQueue.main.async {
                    self.onDeviceDisconnected?(vendorId, productId, serialNumber)
                }
            }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
    
    private func getProperties(for device: io_object_t) -> [String: Any]? {
        var propertiesPtr: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(device, &propertiesPtr, kCFAllocatorDefault, 0)
        
        if result == KERN_SUCCESS, let properties = propertiesPtr?.takeRetainedValue() as? [String: Any] {
            return properties
        }
        return nil
    }
}
