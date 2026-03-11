import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    
    @AppStorage("MenuUSBCenter_PlaySound") private var playSound: Bool = true
    @AppStorage("MenuUSBCenter_SoundType") private var soundTypeRaw: String = SoundManager.SoundType.macDefault.rawValue
    @AppStorage("MenuUSBCenter_ShowNotifications") private var showNotifications: Bool = true
    @AppStorage("MenuUSBCenter_ShowDeviceCount") private var showDeviceCount: Bool = false
    @AppStorage("MenuUSBCenter_HideDisconnected") private var hideDisconnected: Bool = false
    @AppStorage("MenuUSBCenter_HideAdditionalStats") private var hideAdditionalStats: Bool = false
    @AppStorage("MenuUSBCenter_CanonMode") private var canonMode: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Menu USB Center")
                .font(.headline)
                .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 20) {
                // Audio Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Audio Feedback").font(.subheadline).fontWeight(.semibold)
                    
                    HStack {
                        Text("Play sound on connect/disconnect")
                        Spacer()
                        Toggle("", isOn: $playSound).labelsHidden()
                            .toggleStyle(.switch)
                    }
                    
                    if playSound {
                        HStack {
                            Text("Sound Style")
                            Spacer()
                            Picker("", selection: $soundTypeRaw) {
                                ForEach(SoundManager.SoundType.allCases) { type in
                                    Text(type.rawValue).tag(type.rawValue)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                        }
                    }
                }
                
                Divider()
                
                // Notification Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notifications").font(.subheadline).fontWeight(.semibold)
                    
                    HStack {
                        Text("Show Desktop Notifications")
                        Spacer()
                        Toggle("", isOn: $showNotifications).labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: showNotifications) { enabled in
                                NotificationManager.shared.notificationsEnabled = enabled
                            }
                    }
                    
                    Button("Advanced OS Notification Settings...") {
                        // Deep-link to macOS system preferences for notifications
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.caption)
                }
                
                Divider()
                
                // General Settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("General").font(.subheadline).fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Canon Mode (Bluetooth Style)")
                            Text("Mimics macOS Bluetooth menu. Forces UI options below.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $canonMode).labelsHidden()
                            .toggleStyle(.switch)
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    HStack {
                        Text("Show Connected Device Count in Menu Bar")
                        Spacer()
                        Toggle("", isOn: $showDeviceCount).labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .disabled(canonMode)
                    .opacity(canonMode ? 0.5 : 1.0)
                    
                    HStack {
                        Text("Hide Disconnected Devices")
                        Spacer()
                        Toggle("", isOn: $hideDisconnected).labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .disabled(canonMode)
                    .opacity(canonMode ? 0.5 : 1.0)
                    
                    HStack {
                        Text("Hide Additional Device Info (Speed, Serial, etc.)")
                        Spacer()
                        Toggle("", isOn: $hideAdditionalStats).labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .disabled(canonMode)
                    .opacity(canonMode ? 0.5 : 1.0)
                    
                    if #available(macOS 13.0, *) {
                        LaunchAtLoginToggle()
                    }
                }
            }
            .padding(20)
            
            Divider()
            
            // Known Devices List
            VStack(alignment: .leading, spacing: 10) {
                Text("Known Devices")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                Text("Tip: If the trash icon stays grey after disconnect or name appears incorrect, tap 'Edit' then 'Save' to refresh.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                
                if deviceManager.knownDevices.isEmpty {
                    Text("No devices connected yet.")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach($deviceManager.knownDevices) { $device in
                                DeviceRowView(device: $device)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

struct DeviceRowView: View {
    @Binding var device: USBDevice
    @State private var tempAlias: String = ""
    @State private var tempIcon: String = ""
    @State private var isEditing: Bool = false
    
    let availableIcons = [
        "icon.png", "mouse.png", "hub.png", "usb-hub.png",
        "keyboard", "headphones", "speaker.wave.2.fill",
        "mic.fill", "printer.fill", "externaldrive.fill", "display", "camera.fill",
        "gamecontroller.fill", "antenna.radiowaves.left.and.right", "lanyardcard"
    ]
    
    var body: some View {
        HStack(spacing: 12) {
            IconView(name: isEditing ? tempIcon : device.iconName)
                
            VStack(alignment: .leading) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Enter custom name...", text: $tempAlias, onCommit: {
                                commitChanges()
                            })
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: tempAlias) { newValue in
                                if newValue.count > 35 {
                                    tempAlias = String(newValue.prefix(35))
                                }
                            }
                            
                            Button(action: {
                                tempAlias = device.originalName
                                tempIcon = device.defaultIconName
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Reset to Default")
                        }
                        
                        Text("Custom Icon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(availableIcons, id: \.self) { iconName in
                                    Button(action: {
                                        tempIcon = iconName
                                    }) {
                                        IconView(name: iconName, isSelected: tempIcon == iconName)
                                            .padding(2)
                                            .background(tempIcon == iconName ? Color.blue : Color.clear)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                } else {
                    Text(device.displayName)
                        .font(.body)
                    
                    Text("\(device.originalName) (\(device.vendorId):\(device.productId))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isEditing {
                HStack(spacing: 8) {
                    Button("Cancel") {
                        isEditing = false
                    }
                    Button("Save") {
                        commitChanges()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button("Edit") {
                    tempAlias = device.alias ?? device.originalName
                    tempIcon = device.customIcon ?? device.iconName
                    isEditing = true
                }
                
                let isConnected = DeviceManager.shared.currentlyConnected.contains(where: { $0.id == device.id })
                
                Button(action: {
                    DeviceManager.shared.forgetDevice(id: device.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(isConnected ? .gray : .red)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isConnected)
                .help(isConnected ? "Cannot delete currently connected device" : "Delete device")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .onDisappear {
            // Cancel any pending edits if the window is closed
            isEditing = false
        }
    }
    
    private func commitChanges() {
        let finalAlias = tempAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        DeviceManager.shared.updateAlias(for: device.id, alias: finalAlias.isEmpty ? nil : finalAlias)
        
        let finalIcon = tempIcon.isEmpty ? nil : tempIcon
        DeviceManager.shared.updateCustomIcon(for: device.id, icon: finalIcon)
        
        isEditing = false
    }
}

@available(macOS 13.0, *)
struct LaunchAtLoginToggle: View {
    @State private var isEnabled: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack {
            Text("Launch at Login (Starts in background)")
            Spacer()
            Toggle("", isOn: $isEnabled).labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: isEnabled) { newValue in
                    do {
                        if newValue {
                            if SMAppService.mainApp.status != .enabled {
                                try SMAppService.mainApp.register()
                            }
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Failed to update Launch at Login: \(error)")
                        // Revert UI if there was a system error
                        isEnabled = SMAppService.mainApp.status == .enabled
                    }
                }
        }
    }
}
