import Foundation
import IOKit

let matchingDict = IOServiceMatching("IOUSBDevice") as NSMutableDictionary
var iterator: io_iterator_t = 0
IOServiceGetMatchingServices(mach_port_t(MACH_PORT_NULL), matchingDict, &iterator)

var device: io_object_t = IOIteratorNext(iterator)
while device != 0 {
    var propertiesPtr: Unmanaged<CFMutableDictionary>?
    IORegistryEntryCreateCFProperties(device, &propertiesPtr, kCFAllocatorDefault, 0)
    
    if let properties = propertiesPtr?.takeRetainedValue() as? [String: Any] {
        let name = properties["USB Product Name"] as? String ?? "Unknown"
        let speed = properties["Device Speed"] as? Int ?? -1
        print("Device: \(name)")
        print("Speed: \(speed)")
        print("VendorID: \(properties["idVendor"] ?? "nil")")
        print("---")
    }
    
    IOObjectRelease(device)
    device = IOIteratorNext(iterator)
}
IOObjectRelease(iterator)
