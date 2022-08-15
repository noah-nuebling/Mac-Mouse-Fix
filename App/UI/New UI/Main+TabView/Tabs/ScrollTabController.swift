//
//  ScrollTabController.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 16.06.22.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa
import AppKit

@available(macOS 11.0, *)
class ScrollTabController: NSViewController {
    
    /// Config
    
    var smooth = ConfigValue<Bool>(configPath: "Scroll.smooth")
    var inertia = ConfigValue<Bool>(configPath: "Scroll.inertia")
    var naturalDirection = ConfigValue<Bool>(configPath: "Scroll.naturalDirection")
    var scrollSpeed = ConfigValue<String>(configPath: "Scroll.speed")
    var precise = ConfigValue<Bool>(configPath: "Scroll.precise")
    var horizontalMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.horizontal")
    var zoomMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.zoom")
    var swiftMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.swift")
    var preciseMod = ConfigValue<UInt>(configPath: "Scroll.modifiers.precise")
    
    /// Also see `ReactiveFlags` is this doesn't work
    
    /// Outlets
    
    @IBOutlet weak var masterStack: CollapsingStackView!
    
    @IBOutlet weak var smoothToggle: NSButton!
    
    @IBOutlet weak var inertiaSection: NSView!
    @IBOutlet weak var inertiaToggle: NSButton!
    
    @IBOutlet weak var naturalDirectionToggle: NSButton!
    @IBOutlet weak var naturalDirectionHint: NSTextField!
    
    @IBOutlet weak var scrollSpeedPicker: NSPopUpButton!
    
    @IBOutlet weak var preciseSection: NSStackView!
    @IBOutlet weak var preciseToggle: NSButton!
    @IBOutlet weak var preciseHint: NSTextField!
    
    @IBOutlet weak var horizontalModField: ModCaptureTextField!
    @IBOutlet weak var zoomModField: ModCaptureTextField!
    @IBOutlet weak var swiftModField: ModCaptureTextField!
    @IBOutlet weak var preciseModField: ModCaptureTextField!
    @IBOutlet weak var restoreDefaultModsButton: NSButton!
    
    /// Did appear
    
    override func viewDidAppear() {
        let isDisabled = config("Other.scrollKillSwitch") as! Bool /// From the debugger it seems you can only cast NSNumber to bool with as! not with as?. That weird??
        if isDisabled {
            /// Turn off killSwitch
            setConfig("Other.scrollKillSwitch", false as NSObject)
            commitConfig()
            /// Show message to user
            if #available(macOS 13, *) {
                
                /// Build string
                var message = NSAttributedString(coolMarkdown: "Enabled Mac Mouse Fix for __Scrolling__.\nIt had been disabled from the Menu Bar %@")
                let symbolString = NSAttributedString(symbol: "CoolMenuBarIcon", hPadding: 0.0, vOffset: -6, fallback: "<Mac Mouse Fix Menu Bar Item>")
                message = NSAttributedString(attributedFormat: message, args: [symbolString])
                
                /// Show message
                ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1, alignment: kToastNotificationAlignmentTopMiddle)
            } else {
                /// TODO: Make this work on older macOS
            }
        }
    }
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// There was some reason we don't use viewDidLoad here, and instead we use awakeFromNib. I think it had to do with preventing animations from playing when the app starts right into this tab or sth. But maybe it's just unnecessary.
        /// Edit: The replacing between the macOSHint and the preciseSection broke when we used awakeFromNib. Not totally sure why. Let's hope viewDidLoad works after all.
        
        
        /// Smooth
        
        smooth.bindingTarget <~ smoothToggle.reactive.boolValues
        smoothToggle.reactive.boolValue <~ smooth.producer
         
        inertiaSection.reactive.isCollapsed <~ smooth.producer.negate()
        
        /// Inertia
        inertia.bindingTarget <~ inertiaToggle.reactive.boolValues
        inertiaToggle.reactive.boolValue <~ inertia.producer
        
        /// Natural direction
        naturalDirection.bindingTarget <~ naturalDirectionToggle.reactive.boolValues
        naturalDirectionToggle.reactive.boolValue <~ naturalDirection.producer
        naturalDirectionHint.stringValue = "Content tracks finger movement"
        
        /// Scroll speed
        scrollSpeed.bindingTarget <~ scrollSpeedPicker.reactive.selectedIdentifiers.map({ identifier in
            identifier!.rawValue
        })
        scrollSpeedPicker.reactive.selectedIdentifier <~ scrollSpeed.producer.map({ speed in
            NSUserInterfaceItemIdentifier.init(rawValue: speed)
        })
        
        /// Precise
        precise.bindingTarget <~ preciseToggle.reactive.boolValues
        preciseToggle.reactive.boolValue <~ precise.producer
        preciseHint.stringValue = "Scroll precisely by moving the scroll wheel slowly"
        
        /// Installl the macOSHint.
        ///     We manually make the macOSHint width equal the preciseSection width, because if the width changes the window resizes from the left edge which looks crappy.
        ///     This is a really hacky solution. Move this logic into CollapsableStackView (maybe rename to AnimatingStackView or sth).
        ///         Make a method `register(switchableViews:forArrangedSubview:)` which calculates a size that fits all those views, and then you switch between them with `switchTo(view:)`.
        let macOSHint = CoolNSTextField(hintWithString: "Set Scroll Speed at\nSystem Settings > Mouse > Scroll Speed")
        macOSHint.translatesAutoresizingMaskIntoConstraints = false
        macOSHint.setContentHuggingPriority(.required, for: .horizontal)
        macOSHint.setContentHuggingPriority(.required, for: .vertical)
        macOSHint.cell?.wraps = true
        let macOSHintIndent = NSView()
        macOSHintIndent.translatesAutoresizingMaskIntoConstraints = false
        macOSHintIndent.addSubview(macOSHint)
        macOSHint.leadingAnchor.constraint(equalTo: macOSHintIndent/*.layoutMarginsGuide*/.leadingAnchor).isActive = true
        macOSHint.trailingAnchor.constraint(equalTo: macOSHintIndent.trailingAnchor).isActive = true
        macOSHint.topAnchor.constraint(equalTo: macOSHintIndent.topAnchor).isActive = true
        macOSHint.bottomAnchor.constraint(equalTo: macOSHintIndent.bottomAnchor).isActive = true
        preciseSection.needsLayout = true
        preciseSection.window?.layoutIfNeeded()
        let preciseWidth = preciseSection.fittingSize.width
        macOSHintIndent.widthAnchor.constraint(equalToConstant: preciseWidth).isActive = true
        let preciseSectionRetained: NSStackView? = self.preciseSection
        var macOSHintIsDisplaying = false
        if scrollSpeed.get() == "system" {
            self.preciseSection.unanimatedReplace(with: macOSHintIndent)
            macOSHintIsDisplaying = true
        }
        scrollSpeed.producer.skip(first: 1).startWithValues { speed in /// Are we sure to `skip(first: 1)` here?
            if speed == "system" && !macOSHintIsDisplaying {
                self.preciseSection.animatedReplace(with: macOSHintIndent)
                macOSHintIsDisplaying = true
            } else if speed != "system" && macOSHintIsDisplaying {
                macOSHintIndent.animatedReplace(with: preciseSectionRetained!)
                macOSHintIsDisplaying = false
            }
        }
        
        /// Keyboard modifiers
        
        horizontalModField <~ horizontalMod.producer.map({ NSEvent.ModifierFlags(rawValue: $0) })
        horizontalMod <~ horizontalModField.signal.map({ $0.rawValue })
        zoomModField <~ zoomMod.producer.map({ NSEvent.ModifierFlags(rawValue: $0) })
        zoomMod <~ zoomModField.signal.map({ $0.rawValue })
        swiftModField <~ swiftMod.producer.map({ NSEvent.ModifierFlags(rawValue: $0) })
        swiftMod <~ swiftModField.signal.map({ $0.rawValue })
        preciseModField <~ preciseMod.producer.map({ NSEvent.ModifierFlags(rawValue: $0) })
        preciseMod <~ preciseModField.signal.map({ $0.rawValue })
        
        /// Keep these in sync with the `default_config`
        typealias Mods = NSEvent.ModifierFlags
        let defaultH: Mods = [.shift]
        let defaultZ: Mods = [.command]
        let defaultS: Mods = [.control]
        let defaultP: Mods = [.option]
        
        restoreDefaultModsButton.reactive.states.observeValues { state in
            self.horizontalMod.set(defaultH.rawValue)
            self.zoomMod.set(defaultZ.rawValue)
            self.swiftMod.set(defaultS.rawValue)
            self.preciseMod.set(defaultP.rawValue)
        }
        
        let allFlags = SignalProducer<(String, UInt), Never>.merge(horizontalMod.producer.map{ ("h", $0) }, zoomMod.producer.map{ ("z", $0) }, swiftMod.producer.map{ ("s", $0) }, preciseMod.producer.map{ ("p", $0) })
        
        allFlags.startWithValues { (src, flags) in
            
//            DispatchQueue.main.async { /// Need to dispatch async to prevent weird crashes inside ReactiveSwift
                
                if self.horizontalMod.get() == flags && src != "h" {
                    self.horizontalMod.set(0)
                }
                if self.zoomMod.get() == flags && src != "z" {
                    self.zoomMod.set(0)
                }
                if self.swiftMod.get() == flags && src != "s" {
                    self.swiftMod.set(0)
                }
                if self.preciseMod.get() == flags && src != "p" {
                    self.preciseMod.set(0)
                }
                
                var restoreDefaultsIsEnabled = true
                
                if self.horizontalMod.get() == defaultH.rawValue
                    && self.zoomMod.get() == defaultZ.rawValue
                    && self.swiftMod.get() == defaultS.rawValue
                    && self.preciseMod.get() == defaultP.rawValue {
                    
                    restoreDefaultsIsEnabled = false
                }
                
                Animate.with(CABasicAnimation(name: .default, duration: 0.1)) {
                    self.restoreDefaultModsButton.reactiveAnimator().alphaValue.set(restoreDefaultsIsEnabled ? 1.0 : 0.0)
                }
//            }
        }
    }
}