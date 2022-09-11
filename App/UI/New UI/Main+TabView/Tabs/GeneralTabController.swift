//
//  GeneralTabController.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 23.07.21.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import CocoaLumberjackSwift
import Sparkle

class GeneralTabController: NSViewController {
    
    /// Convenience
//    var enabled: MutableProperty<Bool> { MainAppState.shared.appIsEnabled }
    
    /// Config
    var showInMenuBar = ConfigValue<Bool>(configPath: "Other.showMenuBarItem")
    var checkForUpdates = ConfigValue<Bool>(configPath: "Other.checkForUpdates")
    var getBetaVersions = ConfigValue<Bool>(configPath: "Other.checkForPrereleases")
    
    /// Outlets
    
    @IBOutlet var mainView: NSView!
    
    @IBOutlet weak var masterStack: CollapsingStackView!
    
    @IBOutlet weak var enableToggle: NSControl!
    
    @IBOutlet weak var menuBarToggle: NSButton!
    
    @IBOutlet weak var updatesToggle: NSButton!
    @IBOutlet weak var betaToggle: NSButton!
    
    @IBOutlet weak var mainHidableSection: CollapsingStackView!
    @IBOutlet weak var updatesExtraSection: NSView!
    
    
    @IBOutlet weak var enabledHint: NSTextField!
    @IBOutlet weak var updatesHint: NSTextField!
    @IBOutlet weak var menuBarHint: NSTextField!
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Replace enable checkBox with NSSwitch on newer macOS versions
        var usingSwitch = false
        if #available(macOS 10.15, *) {
            
            usingSwitch = true

            let state = enableToggle.value(forKey: "state")

            let switchView = NSSwitcherino()
            
            let superView = enableToggle.superview as! NSStackView
            superView.replaceSubview(enableToggle, with: switchView)
            switchView.addConstraints(transferredSuperViewConstraints(fromView: enableToggle, toView: switchView, transferSizeConstraints: false)) /// Doesn't seem to make a difference currently
            switchView.setContentCompressionResistancePriority(.required, for: .vertical)
            
            self.enableToggle = switchView

            self.enableToggle.setValue(state, forKey: "state")
        }
        
        /// Declare signals
        
        /// enabledToggle <-> Helper enabledState
        
        let onToggle = { doEnable in
            self.enableToggle.intValue = self.enableToggle.intValue == 0 ? 1 : 0
            if doEnable {
                do {
                    try EnabledState.shared.enable()
                } catch {
                    if #available(macOS 13.0, *) {
                        if (error as NSError).code == 1 {
                            do {
                                let messageRaw = NSLocalizedString("is-disabled-toast", comment: "First draft: Mac Mouse Fix was **disabled** in System Settings.\nTo enable Mac Mouse Fix:\n\n1. Go to [Login Items Settings](x-apple.systempreferences:com.apple.LoginItems-Settings.extension)\n2. Switch on \'Mac Mouse Fix.app\'")
                                let message = NSMutableAttributedString(coolMarkdown: messageRaw)
                                
                                if let window = NSApp.mainWindow, let message = message {
                                    ToastNotificationController.attachNotification(withMessage: message, to: window, forDuration: -1.0)
                                }
                            } catch {}
                        }
                    }
                }
            } else { /// !doEnabled
                EnabledState.shared.disable()
            }
        }
        
        if usingSwitch, #available(macOS 10.15, *) {
            (enableToggle as? NSSwitcherino)?.reactive.boolValues.skip(first: 1).startWithValues(onToggle)
        } else {
            enableToggle.reactive.boolValues.observeValues(onToggle) /// Why are we using observe here and startWithValues above?
        }
        
        /// UI <-> data bindings
        
        showInMenuBar <~ menuBarToggle.reactive.boolValues
        checkForUpdates <~ updatesToggle.reactive.boolValues
        getBetaVersions <~ betaToggle.reactive.boolValues
        
        if usingSwitch, #available(macOS 10.15, *) {
            (enableToggle as? NSSwitcherino)?.reactive.boolValue <~ EnabledState.shared
        } else {
            enableToggle.reactive.boolValue <~ EnabledState.shared
        }
        menuBarToggle.reactive.boolValue <~ showInMenuBar
        updatesToggle.reactive.boolValue <~ checkForUpdates
        betaToggle.reactive.boolValue <~ getBetaVersions
        
        mainHidableSection.reactive.isCollapsed <~ EnabledState.shared.producer.negate()
        updatesExtraSection.reactive.isCollapsed <~ checkForUpdates.producer.negate()
        
        /// Side effects: Sparkle
        ///     See `applicationDidFinishLaunching` for context
        
        checkForUpdates.producer.skip(first: 1).startWithValues { doCheckUpdates in
            UserDefaults.standard.removeObject(forKey: "SUSkippedVersion")
            if doCheckUpdates {
                SUUpdater.shared().checkForUpdatesInBackground()
            }
        }
        getBetaVersions.producer.skip(first: 1).startWithValues { doCheckBetas in
            UserDefaults.standard.removeObject(forKey: "SUSkippedVersion")
            SparkleUpdaterController.enablePrereleaseChannel(doCheckBetas)
            if doCheckBetas {
                SUUpdater.shared().checkForUpdatesInBackground()
            }
        }
        
        /// Labels
        
        enabledHint.stringValue = NSLocalizedString("enabled-toggle.hint", comment: "First draft: Mac Mouse Fix will stay enabled after you close it")
        updatesHint.stringValue = NSLocalizedString("updates-toggle.hint", comment: "First draft: You'll be notified of updates when you open\nthis window")
//        menuBarHint.stringValue = NSLocalizedString("menu-bar-toggle.hint", comment: "First draft: Lets you quickly disable Scroll Enhancements and other features")
        
    }
}

// MARK: NSSwitcherino

@available(macOS 10.15, *)
extension Reactive where Base: NSSwitcherino {
    
    var boolValue: BindingTarget<Bool> {
        /// Difference to default implementation
        /// - This animates the state change
        
        return BindingTarget(lifetime: base.reactive.lifetime) { newValue in
            if (base.state == .on) != newValue {
                base.performClick(nil)
            }
        }
    }
    var boolValues: SignalProducer<Bool, Never> {
        /// Difference to default implementation
        /// - Doesn't animate when the user clicks
        return base.signal.producer.prefix(value: base.state == .on)
    }
}
@available(macOS 10.15, *)
@objc fileprivate class NSSwitcherino: NSSwitch {
    
    var signal: Signal<Bool, Never>
    var observer: Signal<Bool, Never>.Observer
    
    required init() {
        let (o, i) = Signal<Bool, Never>.pipe()
        signal = o
        observer = i
        super.init(frame: NSZeroRect)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        self.isHighlighted = true
        let monitorPtr: UnsafeMutablePointer<AnyObject?> = UnsafeMutablePointer.allocate(capacity: 1)
        monitorPtr.pointee = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .leftMouseDragged]) { event in
            if event.type == .leftMouseUp {
                self.isHighlighted = false
                if self == self.window?.contentView?.hitTest(event.locationInWindow) {
                    self.state = self.state == .on ? .off : .on
                    self.observer.send(value: (self.state == .on))
                }
                NSEvent.removeMonitor(monitorPtr.pointee!)
            } else { /// mouseDragged event
                if self == self.window?.contentView?.hitTest(event.locationInWindow) {
                    self.isHighlighted = true
                } else {
                    self.isHighlighted = false
                }
            }
            return event
        } as AnyObject?
    }
}