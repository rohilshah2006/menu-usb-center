import SwiftUI

struct DeviceMenuItemView: View {
    let device: USBDevice
    var hasChildren: Bool = false
    var isConnectedDevice: Bool = true
    
    @AppStorage("MenuUSBCenter_HideAdditionalStats") private var hideAdditionalStats: Bool = false
    @AppStorage("MenuUSBCenter_CanonMode") private var canonMode: Bool = false
    
    var body: some View {
        let effectiveHideStats = canonMode ? true : hideAdditionalStats
        let effectivePadding: CGFloat = canonMode ? 2 : 6
        let effectiveSpacing: CGFloat = canonMode ? 10 : 12
        let nameWeight: Font.Weight = canonMode ? .regular : .bold
        
        HStack(spacing: effectiveSpacing) {
            IconView(name: device.iconName, isConnectedDevice: isConnectedDevice, canonMode: canonMode)
            
            VStack(alignment: .leading, spacing: 4) {
                let hasSerial = device.serialNumber != "UnknownSerial" && !device.serialNumber.isEmpty
                let showChevronInTop = hasChildren && (effectiveHideStats || hasSerial || canonMode)
                let showChevronInBottom = hasChildren && !effectiveHideStats && !hasSerial && !canonMode

                HStack(alignment: .top) {
                    Text(device.displayName)
                        .font(.system(size: 13, weight: nameWeight))
                        .foregroundColor(.primary)
                    
                    Spacer(minLength: 16)
                    
                    if showChevronInTop {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    } else if !effectiveHideStats && !canonMode {
                        if let vendorName = device.vendorName, !vendorName.isEmpty {
                            Text(vendorName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if !effectiveHideStats {
                    HStack(alignment: .top) {
                        Text(device.speed ?? "Unknown Speed")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer(minLength: 16)
                        
                        Text(String(format: "%04X:%04X", device.vendorId, device.productId))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top) {
                        Text("USB Version: \(device.usbVersion ?? "Unknown")")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer(minLength: 16)
                        
                        if hasSerial {
                            Text("SN: \(device.serialNumber)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 150, alignment: .trailing)
                        } else if showChevronInBottom {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, effectivePadding)
        .padding(.horizontal, 12)
        .frame(minWidth: canonMode ? 260 : 320, maxWidth: .infinity, alignment: .leading)
    }
}
