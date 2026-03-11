import Cocoa
import Foundation

class SoundManager {
    static let shared = SoundManager()
    
    private let defaults = UserDefaults.standard
    private let playSoundKey = "MenuUSBCenter_PlaySound"
    private let soundTypeKey = "MenuUSBCenter_SoundType"
    
    enum SoundType: String, CaseIterable, Identifiable {
        case macDefault = "Mac Default"
        case classicPC = "Classic PC"
        var id: String { self.rawValue }
    }
    
    var playSound: Bool {
        get { defaults.object(forKey: playSoundKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: playSoundKey) }
    }
    
    var soundType: SoundType {
        get {
            if let rawValue = defaults.string(forKey: soundTypeKey),
               let type = SoundType(rawValue: rawValue) {
                return type
            }
            return .macDefault
        }
        set { defaults.set(newValue.rawValue, forKey: soundTypeKey) }
    }
    
    private init() {
        // Pre-load default settings if they don't exist
        if defaults.object(forKey: playSoundKey) == nil {
            defaults.set(true, forKey: playSoundKey)
        }
        if defaults.object(forKey: soundTypeKey) == nil {
            defaults.set(SoundType.macDefault.rawValue, forKey: soundTypeKey)
        }
    }
    
    func playConnectSound() {
        guard playSound else { return }
        
        switch soundType {
        case .macDefault:
            if NSSound(named: "DeviceConnect")?.play() != true {
                NSSound(named: "Glass")?.play()
            }
        case .classicPC:
            playCustomSound(name: "classic_connect", ext: "wav")
        }
    }
    
    func playDisconnectSound() {
        guard playSound else { return }
        
        switch soundType {
        case .macDefault:
            if NSSound(named: "DeviceDisconnect")?.play() != true {
                NSSound(named: "Basso")?.play()
            }
        case .classicPC:
            playCustomSound(name: "classic_disconnect", ext: "wav")
        }
    }
    
    private func playCustomSound(name: String, ext: String) {
        let bundle = Bundle.main
        if let path = bundle.path(forResource: name, ofType: ext) {
            let url = URL(fileURLWithPath: path)
            let sound = NSSound(contentsOf: url, byReference: true)
            sound?.play()
        } else {
            print("Sound file \(name).\(ext) not found in bundle!")
        }
    }
}
