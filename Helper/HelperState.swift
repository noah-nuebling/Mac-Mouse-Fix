//
// --------------------------------------------------------------------------
// HelperState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// This class holds global state. Use sparingly!

import Foundation

@objc class HelperState: NSObject {
    
    // MARK: Active device
    /// Might be more appropriate to have this as part of DeviceManager
    
    private static var _activeDevice: Device? = nil
    @objc static var activeDevice: Device? {
        set {
            _activeDevice = newValue
        }
        get {
            if _activeDevice != nil {
                return _activeDevice
            } else { /// Just return any attached device as a fallback
                /// NOTE: Swift let me do `attachedDevices.first` (even thought that's not defined on NSArray) without a compiler warning which did return a Device? but the as! Device? cast still crashed. Using `attachedDevices.firstObject` it doesn't crash.
                return DeviceManager.attachedDevices.firstObject as! Device?
            }
        }
    }
    
    @objc static func updateActiveDevice(event: CGEvent) {
        guard let iohidDevice = CGEventGetSendingDevice(event)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc static func updateActiveDevice(eventSenderID: UInt64) {
        guard let iohidDevice = getSendingDeviceWithSenderID(eventSenderID)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc static func updateActiveDevice(IOHIDDevice: IOHIDDevice) {
        guard let device = DeviceManager.attachedDevice(with: IOHIDDevice) else { return }
        activeDevice = device
    }
}
