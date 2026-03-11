import Foundation

struct USBDevice: Identifiable, Codable, Equatable {
    var id: String { "\(vendorId)-\(productId)-\(serialNumber)" }
    let vendorId: Int
    let productId: Int
    let serialNumber: String
    let originalName: String
    var alias: String?
    var lastConnected: Date
    var speed: String?
    var vendorName: String?
    var usbVersion: String?
    var deviceClass: Int?
    var customIcon: String?
    var parentIdentifier: String?
    
    var defaultIconName: String {
        guard let deviceClass = deviceClass else { return "icon.png" }
        
        switch deviceClass {
        case 1: return "headphones"
        case 2: return "network"
        case 3: return "keyboard"
        case 5: return "gamecontroller"
        case 6: return "camera"
        case 7: return "printer"
        case 8: return "externaldrive.fill"
        case 9: return "hub.png"
        case 10: return "antenna.radiowaves.left.and.right"
        case 11: return "lanyardcard"
        case 14: return "video"
        case 15: return "cross.case"
        case 224: return "antenna.radiowaves.left.and.right"
        case 239: return "applewatch"
        case 254: return "cube.box"
        case 255: return "cpu"
        default: return "icon.png"
        }
    }
    
    var iconName: String {
        if let custom = customIcon, !custom.isEmpty {
            return custom
        }
        return defaultIconName
    }
    
    var isSystemIcon: Bool {
        return !iconName.hasSuffix(".png")
    }
    
    var displayName: String {
        return alias ?? originalName
    }
}

class DeviceManager: ObservableObject {
    static let shared = DeviceManager()
    
    @Published var knownDevices: [USBDevice] = []
    @Published var currentlyConnected: [USBDevice] = []
    
    private let defaults = UserDefaults.standard
    private let devicesKey = "MenuUSBCenter_KnownDevices"
    
    private init() {
        loadDevices()
    }
    
    func deviceConnected(vendorId: Int, productId: Int, serialNumber: String, name: String, speed: String?, vendorName: String?, usbVersion: String?, deviceClass: Int?, parentIdentifier: String?) {
        let deviceId = "\(vendorId)-\(productId)-\(serialNumber)"
        
        var device: USBDevice
        if let existingIndex = knownDevices.firstIndex(where: { $0.id == deviceId }) {
            device = knownDevices[existingIndex]
            device.lastConnected = Date()
            device.speed = speed
            device.vendorName = vendorName
            device.usbVersion = usbVersion
            if let dc = deviceClass {
                device.deviceClass = dc
            }
            if let pId = parentIdentifier {
                device.parentIdentifier = pId
            }
            // Retain the custom icon if it was previously set
            device.customIcon = knownDevices[existingIndex].customIcon
            knownDevices[existingIndex] = device
        } else {
            device = USBDevice(vendorId: vendorId, productId: productId, serialNumber: serialNumber, originalName: name, alias: nil, lastConnected: Date(), speed: speed, vendorName: vendorName, usbVersion: usbVersion, deviceClass: deviceClass, customIcon: nil, parentIdentifier: parentIdentifier)
            knownDevices.append(device)
        }
        
        if !currentlyConnected.contains(where: { $0.id == device.id }) {
            currentlyConnected.append(device)
        }
        
        saveDevices()
    }
    
    func deviceDisconnected(vendorId: Int, productId: Int, serialNumber: String) {
        let deviceId = "\(vendorId)-\(productId)-\(serialNumber)"
        currentlyConnected.removeAll(where: { $0.id == deviceId })
    }
    
    func updateAlias(for deviceId: String, alias: String?) {
        if let index = knownDevices.firstIndex(where: { $0.id == deviceId }) {
            knownDevices[index].alias = alias?.isEmpty == true ? nil : alias
            
            // Also update in currentlyConnected if it's there
            if let connectedIndex = currentlyConnected.firstIndex(where: { $0.id == deviceId }) {
                currentlyConnected[connectedIndex].alias = knownDevices[index].alias
            }
            
            saveDevices()
        }
    }
    
    func updateCustomIcon(for deviceId: String, icon: String?) {
        if let index = knownDevices.firstIndex(where: { $0.id == deviceId }) {
            knownDevices[index].customIcon = icon?.isEmpty == true ? nil : icon
            
            if let connectedIndex = currentlyConnected.firstIndex(where: { $0.id == deviceId }) {
                currentlyConnected[connectedIndex].customIcon = knownDevices[index].customIcon
            }
            
            saveDevices()
        }
    }
    
    func getDevice(vendorId: Int, productId: Int, serialNumber: String) -> USBDevice? {
        let deviceId = "\(vendorId)-\(productId)-\(serialNumber)"
        return knownDevices.first(where: { $0.id == deviceId })
    }
    
    func forgetDevice(id: String) {
        if let index = knownDevices.firstIndex(where: { $0.id == id }) {
            knownDevices.remove(at: index)
            currentlyConnected.removeAll(where: { $0.id == id })
            saveDevices()
        }
    }
    
    private func saveDevices() {
        if let encoded = try? JSONEncoder().encode(knownDevices) {
            defaults.set(encoded, forKey: devicesKey)
        }
    }
    
    private func loadDevices() {
        if let data = defaults.data(forKey: devicesKey),
           let decoded = try? JSONDecoder().decode([USBDevice].self, from: data) {
            knownDevices = decoded
        }
    }
}
