import Cocoa
import SwiftUI
import Foundation
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Load the sharp PNG icon for the menu bar
        if let button = statusItem.button {
            if let originalImg = NSImage(named: "icon.png") {
                let img = originalImg.resized(to: NSSize(width: 18, height: 18))
                img.isTemplate = true
                button.image = img
            } else if let fallbackImg = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "USB Devices") {
                button.image = fallbackImg
            } else {
                button.title = "USB"
            }
        }
        
        // Initialize Notification Center
        _ = NotificationManager.shared
        
        // --- Setup persistent NSMenu with delegate ---
        let mainMenu = NSMenu()
        mainMenu.delegate = self
        statusItem.menu = mainMenu
        
        updateMenuBadge()
        
        // Observe changes to connected devices and rebuild the menu
        DeviceManager.shared.$currentlyConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBadge()
                self?.statusItem.menu?.update()
            }
            .store(in: &cancellables)
            
        // Also observe changes to knownDevices to update aliases in real-time
        DeviceManager.shared.$knownDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusItem.menu?.update()
            }
            .store(in: &cancellables)
            
        // Observe UserDefaults changes so we can toggle the badge count instantly when settings change
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateMenuBadge()
            self?.statusItem.menu?.update()
        }
        
        USBMonitor.shared.start()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        USBMonitor.shared.stop()
    }

    func updateMenuBadge() {
        if let button = statusItem.button {
            let connectedDevices = DeviceManager.shared.currentlyConnected
            let showCount = UserDefaults.standard.bool(forKey: "MenuUSBCenter_ShowDeviceCount")
            let canonMode = UserDefaults.standard.bool(forKey: "MenuUSBCenter_CanonMode")
            if showCount && !canonMode && !connectedDevices.isEmpty {
                button.title = " \(connectedDevices.count)"
            } else {
                button.title = ""
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let canonMode = UserDefaults.standard.bool(forKey: "MenuUSBCenter_CanonMode")
        
        if canonMode {
            let headerItem = NSMenuItem()
            let hostingView = NSHostingView(rootView:
                Text("USB Devices")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
            hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
            hostingView.autoresizingMask = [.width]
            headerItem.view = hostingView
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        let connectedDevices = DeviceManager.shared.currentlyConnected
        let allKnownDevices = DeviceManager.shared.knownDevices
        let disconnectedDevices = allKnownDevices.filter { known in 
            !connectedDevices.contains(where: { $0.id == known.id }) 
        }
        
        // --- 1. Connected Devices ---
        if connectedDevices.isEmpty && !canonMode {
            let placeholderItem = NSMenuItem(title: "No devices connected", action: nil, keyEquivalent: "")
            placeholderItem.isEnabled = false
            menu.addItem(placeholderItem)
        } else {
            // Find root devices (devices that have no parent or whose parent is not currently connected)
            let rootDevices = connectedDevices.filter { device in
                if let pId = device.parentIdentifier {
                    return !connectedDevices.contains(where: { $0.id.hasPrefix(pId) })
                }
                return true
            }
            
            for device in rootDevices {
                addMenuNodes(for: device, to: menu, connectedDevices: connectedDevices, allKnownDevices: allKnownDevices)
            }
        }
        
        // Remove the extra separator at the end if we added devices
        if !connectedDevices.isEmpty && menu.numberOfItems > 0 {
            if menu.item(at: menu.numberOfItems - 1)?.isSeparatorItem ?? false {
                menu.removeItem(at: menu.numberOfItems - 1)
            }
        }
        
        // Remove the extra separator at the end if we added devices
        if !connectedDevices.isEmpty && menu.numberOfItems > 0 {
            if menu.item(at: menu.numberOfItems - 1)?.isSeparatorItem ?? false {
                menu.removeItem(at: menu.numberOfItems - 1)
            }
        }
        
        // --- 2. Disconnected Devices ---
        let hideDisconnected = canonMode ? false : UserDefaults.standard.bool(forKey: "MenuUSBCenter_HideDisconnected")
        
        if !hideDisconnected && !disconnectedDevices.isEmpty {
            if !canonMode {
                menu.addItem(NSMenuItem.separator())
                
                let headerItem = NSMenuItem(title: "Disconnected Devices", action: nil, keyEquivalent: "")
                headerItem.isEnabled = false
                headerItem.attributedTitle = NSAttributedString(string: "Disconnected Devices", attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
                ])
                menu.addItem(headerItem)
            }
            
            for device in disconnectedDevices {
                if canonMode {
                    let currentItem = NSMenuItem()
                    let hostingView = NSHostingView(rootView: DeviceMenuItemView(device: device, hasChildren: false, isConnectedDevice: false))
                    hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
                    hostingView.autoresizingMask = [.width]
                    currentItem.view = hostingView
                    currentItem.isEnabled = false
                    menu.addItem(currentItem)
                } else {
                    let item = NSMenuItem(title: device.displayName, action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    // Grey out disconnected devices to visually distinguish them
                    item.attributedTitle = NSAttributedString(string: device.displayName, attributes: [
                        .foregroundColor: NSColor.disabledControlTextColor
                    ])
                    
                    // Keep the icon for disconnected devices
                    if device.iconName.hasSuffix(".png") {
                        if let originalImg = NSImage(named: device.iconName) {
                            let img = originalImg.resized(to: NSSize(width: 18, height: 18))
                            img.isTemplate = true
                            item.image = img
                        }
                    } else {
                        item.image = NSImage(systemSymbolName: device.iconName, accessibilityDescription: "Disconnected USB")
                    }
                    menu.addItem(item)
                }
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Preferences option
        let settingsItem = NSMenuItem(title: "USB Center Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)
        
        // Add Quit option
        menu.addItem(NSMenuItem(title: "Quit Menu USB Center", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
    
    private func addMenuNodes(for device: USBDevice, to menu: NSMenu, connectedDevices: [USBDevice], allKnownDevices: [USBDevice]) {
        let latestDevice = allKnownDevices.first(where: { $0.id == device.id }) ?? device
        
        // Find all children strictly connected to this device's UUID
        let children = connectedDevices.filter { child in
            if let pId = child.parentIdentifier {
                return device.id.hasPrefix(pId)
            }
            return false
        }
        
        let currentItem = NSMenuItem()
        
        // Wrap the SwiftUI view inside an NSHostingView
        let hostingView = NSHostingView(rootView: DeviceMenuItemView(device: latestDevice, hasChildren: !children.isEmpty))
        hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
        hostingView.autoresizingMask = [.width]
        
        currentItem.view = hostingView
        
        if !children.isEmpty {
            // macOS natively draws a sub-menu arrow indicator if a submenu is attached, 
            // but ONLY if the parent item itself has a title. Items with only a `.view`
            // and no title text won't draw the system arrow. We give it a space to force the arrow layout.
            currentItem.title = " "
            
            let submenu = NSMenu()
            for child in children {
                addMenuNodes(for: child, to: submenu, connectedDevices: connectedDevices, allKnownDevices: allKnownDevices)
            }
            currentItem.submenu = submenu
        } else {
            currentItem.isEnabled = false
        }
        
        menu.addItem(currentItem)
        
        let canonMode = UserDefaults.standard.bool(forKey: "MenuUSBCenter_CanonMode")
        
        // Only append separator to the root-level menu to keep it grouped nicely
        if menu == statusItem.menu && !canonMode {
            menu.addItem(NSMenuItem.separator())
        }
    }
    
    var settingsWindow: NSWindow?
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.minSize = NSSize(width: 450, height: 300)
            settingsWindow?.maxSize = NSSize(width: 450, height: CGFloat.greatestFiniteMagnitude)
            
            settingsWindow?.title = "Menu USB Center Settings"
            settingsWindow?.contentViewController = hostingController
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("SettingsWindow")
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: .zero,
                  operation: .sourceOver,
                  fraction: 1.0)
        newImage.unlockFocus()
        newImage.isTemplate = self.isTemplate
        return newImage
    }
}
