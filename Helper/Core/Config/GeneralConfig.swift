//
// --------------------------------------------------------------------------
// GeneralConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Cocoa

@objc class GeneralConfig: NSObject {

    private static var _generalConfigRaw: NSDictionary? = nil
    
    @objc static func reload() {
        
        /// Guard equal
        let new = config("General") as! NSDictionary?
        
        guard !(new?.isEqual(to: _generalConfigRaw) ?? false) else {
            return
        }
        
        /// Store
        _generalConfigRaw = new?.copy() as! NSDictionary?  
        
        /// Notify
        if let new = new {
            SwitchMaster.shared.generalConfigChanged(generalConfig: new)
        } else {
            assert(false)
        }
    }
    
    /// Advanced settings
    
    @objc static func freezePointerDuringModifiedDrag() -> Bool {
        return config("General.lockPointerDuringDrag") as! Bool
    }
    @objc static var doubleClickThreshold: Double {
        return 0.01;
    }
    
    /// Internal
    
    @objc static func mouseMovingMaxIntervalLarge() -> Double {
        return 0.1
    }
    
    @objc static func mouseMovingMaxIntervalSmall() -> Double {
        return 0.04
        /// ^ Only consider the mouse moving, if less than this time interval has passed between the last two events
        /// Notes from using this in ModifiedDrag:
        /// - 0.05 is a little too low. It will sometimes stop when you don't want it to when driving it through click and drag.
        /// - 0.07 is still a little low when the computer is laggy
        /// - I settled on 0.1
        /// Edit: I'm also using this in PointerFreeze now, and there 0.04 or lower seems appropriate (But my computer is also running fast at the moment). Won't go into why, but I think it's probably better to heir on the side of larger for MomentumScroll and smaller for PointerFreeze. -> I'll create two values: mouseMovingMaxIntervalLarge, and mouseMovingMaxIntervalSmall.
    }
    
}
