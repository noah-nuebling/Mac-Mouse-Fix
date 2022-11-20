//
// --------------------------------------------------------------------------
// AboutTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Cocoa

class AboutTabController: NSViewController {

//    var isLicensed = ConfigValue<Bool>(configPath: "License.isLicensedCache")
    
    /// Outlets and vars
    
    @IBOutlet weak var versionField: NSTextField!
    
    @IBOutlet weak var moneyCell: NSView!
    @IBOutlet weak var moneyCellLink: Hyperlink!
    @IBOutlet weak var moneyCellImage: NSImageView!
    
    var trialSectionManager: TrialSectionManager?
    @IBOutlet weak var trialCell: TrialSection! /// TODO: Rename to trialSection
    
    var payButtonWrapper: NSView? = nil
    var payButtonwrapperConstraints: [NSLayoutConstraint] = []
    
    var currentLicenseConfig: LicenseConfig? = nil
    var currentLicense: MFLicenseAndTrialState? = nil

    var trackingArea: NSTrackingArea? = nil
    
    /// IBActions
    
    @IBAction func sendEmail(_ sender: Any) {
        
        /// Create alert
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("mail-alert.title", comment: "First draft: Write an Email?")
        alert.informativeText = NSLocalizedString("mail-alert.body", comment: "First draft: I can't respond to all emails but I read and am happy about all feedback!")
//        alert.showsSuppressionButton = true
        alert.addButton(withTitle: NSLocalizedString("mail-alert.send", comment: "First draft: Write Email"))
        alert.addButton(withTitle: NSLocalizedString("mail-alert.back", comment: "First draft: Back"))
        
        /// Set mail icon
        
        if let mailURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "mailto:noah.n.public@gmail.com")!) {
            
            let mailPath: String
            if #available(macOS 13.0, *) {
                mailPath = mailURL.path(percentEncoded: false)
            } else {
                mailPath = mailURL.path
            }
            let mailIcon = NSWorkspace.shared.icon(forFile: mailPath)
            
            alert.icon = mailIcon
        }
        
        /// Display alert
        guard let window = MainAppState.shared.window else { return }
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "mailto:noah.n.public@gmail.com")!)
            }
        }
    }
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Store self in MainAppState for global access
        
        MainAppState.shared.aboutTabController = self
        
        /// Set up versionField
        
        versionField.stringValue = "\(Locator.bundleVersionShort()) (\(Locator.bundleVersion()))"
        
        /// Init trialSectionManager
        ///     The manager swaps out the trialSection and stuff, so always access the trialSection through the manager!
        trialSectionManager = TrialSectionManager(trialCell)
        
        /// Get licensing info
        ///     Notes:
        ///     - Not using the completionHandler of `Licensing.licensingState` here since it's asynchronous. However, calling `licensingState()` will update isLicensed and then the UI will update. We could also have separated ConfigValue for the daysOfUse config value, but I don't think it'll be noticable if that doesn't update totally correctl
        
        /// Get cache
        let cachedLicenseConfig = LicenseConfig.getCached()
        let cachedLicense = License.checkLicenseAndTrialCached(licenseConfig: cachedLicenseConfig)
        
        /// 1. Set UI to cache
        updateUI(licenseConfig: cachedLicenseConfig, license: cachedLicense)
            
        /// 2. Get real values and update UI again
//        updateUIToCurrentLicense()
        
    }
    
    /// Did appear
    
    override func viewDidAppear() {
        /// 2. Get real values and update UI
        updateUIToCurrentLicense()
    }
    
    /// Update UI
    
    func updateUIToCurrentLicense() {
            
        /// This is called on load and when the user activates/deactivates their license.
        /// - It would be cleaner and prettier if we used a reactive architecture where you have some global master license state that all the UI that depends on it subscribes to. Buttt we really only have UI that depends on the license state here on the about tab, so that would be overengineering. On the other hand we need to store the AboutTabController instance in MainAppState for global access if we don't use th reactive architecture which is also a little ugly.
        
        LicenseConfig.get { licenseConfig in
            License.checkLicenseAndTrial(licenseConfig: licenseConfig, completionHandler: { license, error in
                
                DispatchQueue.main.async {
                    self.updateUI(licenseConfig: licenseConfig, license: license)
                }
                
            })
        }
    }
    
    func updateUI(licenseConfig: LicenseConfig, license: MFLicenseAndTrialState) {
        
        /// Guard no change
        if currentLicenseConfig?.isEqual(to: licenseConfig) ?? false && currentLicense == license { return }
        currentLicenseConfig = licenseConfig; currentLicense = license
        
        /// Deactivate tracking area
        if let trackingArea = self.trackingArea {
            self.view.removeTrackingArea(trackingArea)
        }
        
        if license.isLicensed.boolValue {
            
            ///
            /// Replace payButton with milkshake link
            ///
            
            /// Note: This only does something if the UI was first updated in the unlicensed state and now it's going back to licensed state. When we hit this straight after loading from IB, the payButtonWrapper will just be nil and the moneyCellLink will be unhidden already, and the moneyCellImage will be the milkshake already, and the trackingArea will be nil (I think?), so this won't do anything.
            
            /// Show link and hide payButton
            self.payButtonWrapper?.isHidden = true
            self.moneyCellLink.isHidden = false
            
            /// Swap shopping bag image for milkshake image
            ///     Not sure if the scaling and symbol config is necessary here?
            
            self.moneyCellImage.imageScaling = .scaleNone
            if #available(macOS 11.0, *) {
                self.moneyCellImage.symbolConfiguration = .init(scale: .large)
            }
            self.moneyCellImage.image = NSImage(named: .init("LittleMilkshakeOutlines"))
            
            ///
            /// Replace trial section with thank you section
            ///
            
            /// Stop managing trial section
            ///     So we can do manual manipulations
            trialSectionManager?.stopManaging()
            
            /// HACK: Turn of clipping
            ///     The fact that this is necessary, means there's something I don't understand.
            ///     Explanation:
            ///         - The clipping is originally turned off via User Defined Runtime Attributes in IB. Then the view is saved, swapped out with animations on mouse hover, and restored by trialSectionManager. We know it's restored at this point because we just called trialSectionManager.stopManaging(). But still the clipping is reset somehow.
            ///     Ideas for why this might be necessary:
            ///         - Maybe we're not correctly swapping back to the original view from interface builder.
            ///         - Maybe the clipping settings are not saved when trialSectionManager saves and restores the view from IB
            trialSectionManager?.currentSection.imageView?.layer?.masksToBounds = false
            
            /// Randomly select 1 out of 25+1 messages
            ///     Note: If you want to test one of the rare ones, increase its `weight`
            
            var message: String = "Something went wrong! You shouldn't be seeing this."
            
            switch license.licenseReason {
                
            case kMFLicenseReasonFreeCountry:
                
                /// Get current region
                let regionCode: String?
                if #available(macOS 13, *) {
                    regionCode = Locale.current.region?.identifier
                } else {
                    regionCode = Locale.current.regionCode
                }
                
                /// Get localized country name + flag emoji
                var countryName = "Unknown Country"
                var flag = "🏁"
                if let regionCode = regionCode  {
                    if let n = Locale.current.localizedString(forRegionCode: regionCode) {
                        countryName = n
                    }
                    if let f = UIStrings.flagEmoji(regionCode) {
                        flag = f
                    }
                } else {
                    assert(false)
                }
                
                /// Assemble message
                
                let countryString = String(format: "%@ %@", countryName, flag)
                
                message = String(format: NSLocalizedString("free-country", comment: "First draft: Mac Mouse Fix is currently free in your country (%@)"), countryString)
                
            case kMFLicenseReasonForce:
                message = "The app will appear to be licensed due to the FORCE_LICENSED flag"
            case kMFLicenseReasonNone:
                assert(false)
                fallthrough
            case kMFLicenseReasonUnknown:
                assert(false)
                fallthrough
            case kMFLicenseReasonValidLicense:
                
                message = Randomizer.select(from: [
                    
                    /// Common
                    (NSLocalizedString("thanks.01", comment: "First draft: 💫 Thank you for buying Mac Mouse Fix!"), weight: 1),
                    (NSLocalizedString("thanks.02", comment: "First draft: 🌟 Thanks for purchasing Mac Mouse Fix!"), weight: 1),
                    (NSLocalizedString("thanks.03", comment: "First draft: 🚀 Thanks for supporting Mac Mouse Fix!"), weight: 1),
                    (NSLocalizedString("thanks.04", comment: "First draft: 🙏 Thank you for buying Mac Mouse Fix!"), weight: 1),
                    (NSLocalizedString("thanks.05", comment: "First draft: 🧠 Great purchasing decisions ;)"), weight: 1),
                    
                    /// Rare
                    (NSLocalizedString("thanks.06", comment: "First draft: 🔥 Awesome taste in mouse fixing software ;)"), weight: 0.1),
                    (NSLocalizedString("thanks.07", comment: "First draft: 💙"), weight: 0.1),
                    (NSLocalizedString("thanks.08", comment: "First draft: :) <- My face when I saw you bought Mac Mouse Fix"), weight: 0.1),
                    
                    /// Very rare
                    (NSLocalizedString("thanks.09", comment: "First draft: 👽 Share it with your Spacebook friends!"), weight: 0.05),
                    
                    /// Extremely rare
                    (NSLocalizedString("thanks.10", comment: "First draft: 🏂 Duckgang for life! || Note: A lot of these are very personal. And weir. They are also super rare. Feel free to change them to anything you feel like to leave a little easter egg!"), weight: 0.01),
                    (NSLocalizedString("thanks.11", comment: "First draft: 🚜 Watch where you're going :P"), weight: 0.01),
                    (NSLocalizedString("thanks.12", comment: "First draft: 🐁 Not these mice, mom!"), weight: 0.01),
                    (NSLocalizedString("thanks.13", comment: "First draft: 🐹 We should get him a bow tie."), weight: 0.01),
                    (NSLocalizedString("thanks.14", comment: "First draft: 🇹🇷 Ey Kanka, tebrikler tebrikler!"), weight: 0.01),
                    (NSLocalizedString("thanks.15", comment: "First draft: 🥛 Whole milk of course! It's your birthday after all."), weight: 0.01),
                    (NSLocalizedString("thanks.16", comment: "First draft: 🎸 Not John Mayer (yet). Nevertheless mayor of hearts."), weight: 0.01),
                    (NSLocalizedString("thanks.17", comment: "First draft: 💃 1NEIN8NEIN"), weight: 0.01),
                    (NSLocalizedString("thanks.18", comment: "First draft: 🦋 Give me a call when you saved the world :)"), weight: 0.01),
                    (NSLocalizedString("thanks.19", comment: "First draft: 🏜️ Dankeschön, meine Frau..."), weight: 0.01),
                    (NSLocalizedString("thanks.20", comment: "First draft: 🌍 Universal Studios is probably not that great anyways... :)"), weight: 0.01),
                    (NSLocalizedString("thanks.21", comment: "First draft: 🐠 What... are... you?"), weight: 0.01),
                    (NSLocalizedString("thanks.22", comment: "First draft: 🖤"), weight: 0.01),
                    (NSLocalizedString("thanks.23", comment: "First draft: 🤍"), weight: 0.01),
                    (NSLocalizedString("thanks.24", comment: "First draft: 😎 Oh you're using Mac Mouse Fix? You must be pretty cool."), weight: 0.01),
                    (NSLocalizedString("thanks.25", comment: "First draft: 🌏 First the mice, then the world!! >:)"), weight: 0.01),
                    
                    /// Mom
                    ("💖❤️❤️❤️ Für Beate, meine Lieblingsperson :)", weight: 0.005),
                ])
            default:
                fatalError()
            }
            
            /// Parse markdown in message
            let messageAttributed = NSAttributedString(coolMarkdown: message, fillOutBase: false)!
            
            /// Replace text
            assignAttributedStringKeepingBase(&trialSectionManager!.currentSection.textField!.attributedStringValue, messageAttributed)
            
            /// Remove calendar image
            trialSectionManager!.currentSection.imageView!.image = nil
            
        } else /** not licensed */ {
            
            ///
            /// Setup trial section
            ///
            
            /// Begin managing
            trialSectionManager?.startManaging(licenseConfig: licenseConfig, license: license)
            
            /// Set textfield height
            ///     Necessary for y centering. Not sure why
            ///     Edit: Not necessary anymore since we're using the trialSectionManager. Not sure why.
            
//            trialSectionManager!.trialSection.textField!.heightAnchor.constraint(equalToConstant: 20).isActive = true

            
            if license.trialIsActive.boolValue {
                
                /// Update layout
                ///     So tracking area frames / bounds are correct
                trialSectionManager?.currentSection.needsLayout = true
                trialSectionManager?.currentSection.superview?.needsLayout = true
                trialSectionManager?.currentSection.superview?.layoutSubtreeIfNeeded()
                
                /// Setup tracking area
                trackingArea = NSTrackingArea(rect: trialSectionManager!.currentSection.superview!.bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited], owner: self)
                trialSectionManager!.currentSection.superview!.addTrackingArea(trackingArea!)
                
            } else { /// Trial has expired
                
                /// Always show activate button
                trialSectionManager?.showActivate()
            }
            
            ///
            /// Set up money section
            ///
            
            /// Swap out milkshake -> shopping bag
            ///     Don't know how to set scale pre macOS 11.0 Big Sur. So it'll just look a little crappy.
            ///     Alt idea for the symbol: "tag"
            
            self.moneyCellImage.imageScaling = .scaleNone
            if #available(macOS 11.0, *) {
                self.moneyCellImage.symbolConfiguration = .init(pointSize: 13, weight: .medium, scale: .large)
            }
            self.moneyCellImage.image = Symbols.image(withSymbolName: "bag")
            
            /// Swap out link -> payButton
            
            /// Create paybutton
            
            let payButton = PayButton(title: licenseConfig.formattedPrice, action: {
                LicenseUtility.buyMMF(licenseConfig: licenseConfig, locale: Locale.current, useQuickLink: false)
            })
            
            /// Insert payButton into wrapper
            ///     We need a wrapper because the superView wants its subview to be full width, But we want the payButton to be left-aligned
            
            self.payButtonWrapper = NSView()
            self.payButtonWrapper!.translatesAutoresizingMaskIntoConstraints = false
            self.payButtonWrapper!.wantsLayer = true
            self.payButtonWrapper!.layer?.masksToBounds = false
            
            self.payButtonWrapper!.addSubview(payButton)
            self.payButtonWrapper!.snp.makeConstraints { make in
                make.top.equalTo(payButton.snp.top)
                make.centerY.equalTo(payButton.snp.centerY)
                make.leading.equalTo(payButton.snp.leading)
            }
            
            /// Create Apple Pay badge
            let image = NSImage(named: "ApplePay")!
            let badge = NSImageView(image: image)
            
            badge.enableAntiAliasing()

            if #available(macOS 10.14, *) {
                badge.contentTintColor = .labelColor
            }
            
            /// Insert Apple Pay badge into wrapper
            self.payButtonWrapper!.addSubview(badge)
            badge.snp.makeConstraints { make in
                make.centerY.equalTo(payButton.snp.centerY)
                make.leading.equalTo(payButton.snp.trailing).offset(9)
                make.width.equalTo(20)
            }
            
            /// Insert wrapper into UI
            self.payButtonwrapperConstraints = transferredSuperViewConstraints(fromView: self.moneyCellLink, toView: self.payButtonWrapper!, transferSizeConstraints: false)
            self.moneyCell.addSubview(self.payButtonWrapper!)
            for c in self.payButtonwrapperConstraints {
                c.isActive = true
            }
            
            /// Hide link
            self.moneyCellLink.isHidden = true
            
        }
    }
    
    /// Tracking area calllbacks
    
    override func mouseEntered(with event: NSEvent) {
        
        DispatchQueue.main.async {
            self.trialSectionManager?.showActivate()
        }
    }
    override func mouseExited(with event: NSEvent) {
        
        DispatchQueue.main.async {
            self.trialSectionManager?.showTrial()
        }
    }
}
