import SwiftUI

struct IconView: View {
    let name: String
    var isSelected: Bool = false
    var size: CGFloat = 36
    var iconSize: CGFloat = 20
    var isGreyscale: Bool = false
    
    var isConnectedDevice: Bool = true
    var canonMode: Bool = false
    
    var body: some View {
        ZStack {
            let canonCircleFill = isConnectedDevice ? Color.blue : Color.gray.opacity(0.15)
            let standardCircleFill = isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.2)
            
            let effectiveSize = canonMode ? 28.0 : size
            let effectiveIconSize = canonMode ? 14.0 : iconSize
            
            Circle()
                .fill(canonMode ? canonCircleFill : standardCircleFill)
                .frame(width: effectiveSize, height: effectiveSize)
            
            if name.hasSuffix(".png") {
                if let nsImage = templateImage(named: name) {
                    let isSpecialLargeIcon = ["mouse.png", "hub.png", "usb-hub.png"].contains(name)
                    let currentIconSize = isSpecialLargeIcon ? effectiveSize * (canonMode ? 0.7 : 0.8) : effectiveIconSize
                    
                    let canonIconColor = isConnectedDevice ? Color.white : Color.primary
                    let standardIconColor = isSelected ? Color.white : (isGreyscale ? Color(NSColor.disabledControlTextColor) : Color.primary)
                    let finalColor = canonMode ? canonIconColor : standardIconColor
                    
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: currentIconSize, height: currentIconSize)
                        .foregroundColor(finalColor)
                        .id(name)
                } else {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: effectiveIconSize))
                        .foregroundColor(.secondary)
                        .id("question")
                }
            } else {
                let canonIconColor = isConnectedDevice ? Color.white : Color.primary
                let standardIconColor = isSelected ? Color.white : (isGreyscale ? Color(NSColor.disabledControlTextColor) : Color.primary)
                let finalColor = canonMode ? canonIconColor : standardIconColor
                
                Image(systemName: name)
                    .font(.system(size: effectiveIconSize))
                    .foregroundColor(finalColor)
                    .id(name)
            }
        }
    }
    
    private func templateImage(named: String) -> NSImage? {
        if let img = NSImage(named: named) {
            let copy = img.copy() as! NSImage
            copy.isTemplate = true
            return copy
        }
        return nil
    }
}
