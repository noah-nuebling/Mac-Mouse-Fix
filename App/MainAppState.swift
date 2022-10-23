//
//  AppState.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 2/11/22.
//

/// Don't overuse this or things will get messy!

import Cocoa
import ReactiveSwift

// MARK: Main State

@objc class MainAppState: NSObject {
    
    /// Declare singleton instance
    @objc static let shared = MainAppState()

    /// References
    
    @objc var window: ResizingTabWindow? {
        return NSApp.mainWindow as? ResizingTabWindow
    }
    @objc var appDelegate: AppDelegate {
        return NSApp.delegate as! AppDelegate
    }
    @objc var tabViewController: TabViewController? {
        let controller = NSApp.mainWindow?.contentViewController as! TabViewController?
        return controller
    }
    
    /// References to specific views
    ///     Are we sure we need this all these?? Seems a little messy to expose these globally
    @objc var remapTableController: RemapTableController? = nil
    @objc var remapTable: RemapTableView? { remapTableController?.view as? RemapTableView }
    @objc var buttonTabController: ButtonTabController? = nil
    @objc var aboutTabController: AboutTabController? = nil
}

// MARK: Helper enabled state

@objc class EnabledState: NSObject, BindingSource {
        
    /// EnabledState is a reactive interface for enabling the helper.  (The app being enabled/disabled and the helper being enabled/disabled are considered equivalent)
    
    /// Binding source protocol
    var producer: SignalProducer<Bool, Never> {

        /// Cache `latest` so isEnabled isn't called over and over, because that slows things down.
        if latest == nil {
            latest = isEnabled()
        }
        return signal.producer.prefix(value: latest!)
    }
    typealias Error = Never
    typealias Value = Bool
    
    /// Declare singleton instance
    @objc static let shared = EnabledState()
    
    /// Storage
    var latest: Bool? = nil
    let signal: Signal<Bool, Never>
    let observer: Signal<Bool, Never>.Observer
    
    /// Init
    override init() {
        
        let (o, i) = Signal<Bool, Never>.pipe()
        signal = o
        observer = i
        
        super.init()
        
        signal.observeValues { isEnabled in
            self.latest = isEnabled
        }
    }
    
    /// Main interface
    
    @objc func enable(onComplete: ((NSError?) -> Void)?) {
        HelperServices.enableHelperAsUserAgent(true) { swiftError in
            onComplete?(swiftError as NSError?) /// Swift converts the NSError that `.enableHelperAsUserAgent` returns to it's onComplete arg to some weird abstract Swift error, so we have to cast it back here. Swift is sooooo annoying I swear to god.
        }
    }
    @objc func disable() {
        HelperServices.enableHelperAsUserAgent(false, onComplete: nil)
        observer.send(value: false)
    }
    func isEnabled() -> Bool {
        HelperServices.helperIsActive()
    }
    
    /// ObjC compat
    @objc func reactToDidBecomeEnabled() {
        observer.send(value: true)
    }
    @objc func reactToDidBecomeDisabled() {
        observer.send(value: false)
    }
}
