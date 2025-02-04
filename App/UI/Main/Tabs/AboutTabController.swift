//
// --------------------------------------------------------------------------
// AboutTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

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
    
    var currentIsLicensed: Bool? = nil
    var currentLicenseConfig: MFLicenseConfig? = nil
    var currentLicenseState: MFLicenseState? = nil
    var currentTrialState: MFTrialState? = nil

    private var trackingArea: NSTrackingArea? = nil
    
    /// IBActions
    
    @IBAction func sendEmail(_ sender: Any) {
        
        /// Create alert
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("mail-alert.title", comment: "First draft: Write an Email?")
        alert.informativeText = NSLocalizedString("mail-alert.body", comment: "First draft: I read and appreciate all emails, even though I can't respond to all")
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
        
        // TODO: Links to Acknowledgements, Readme and Website should probably be localized.
        
        /// Set up versionField
        /// Notes:
        ///  - Explanation for `let versionFormatExists =` logic: If the key doesn't exist in Localizable.strings, then `NSLocalizedStringgg()` returns the key. But bartycrouch (I think) automatically creates the key and initializes it to emptyString.
        ///     (Note: Don't use NSLocalizedStringggg real name in comments or BartyCrouch gets confused.)
        ///  - We're handling the case that the `app-version` key doesn't exist here, because we're adding the version-format stuff right before the 3.0.0 release, and the Korean and Chinese translations don't contain the 'app-version' key, yet.
        
        let versionFormat = NSLocalizedString("app-version", comment: "First draft: Version %@ || Note: %@ will be replaced by the app version, e.g. '3.0.0 (22027)'")
        let versionFormatExists = versionFormat.count != 0 && versionFormat != "app-version"
        let versionNumbers = "\(Locator.bundleVersionShort()) (\(Locator.bundleVersion()))"
        versionField.stringValue = versionFormatExists ? String(format: versionFormat, versionNumbers) : versionNumbers
        
        /// Init trialSectionManager
        ///     The manager swaps out the trialSection and stuff, so always access the trialSection through the manager!
        trialSectionManager = TrialSectionManager(trialCell)
        
        /// Get licensing info
        ///     Notes:
        ///     - Not using the completionHandler of `Licensing.licensingState` here since it's asynchronous. However, calling `licensingState()` will update isLicensed and then the UI will update. We could also have separated ConfigValue for the daysOfUse config value, but I don't think it'll be noticable if that doesn't update totally correctl
        ///         - Update: Oct 2024: This is totally outdated and I don't know what it means anymore.
        
        /// Get cache
        let (cachedLicenseConfig, cachedLicenseState, cachedTrialState) = License.checkLicenseAndTrial_Preliminary()
        
        /// Step 1: Set UI to cache
        if cachedLicenseState.isLicensed {
            updateUI_WithIsLicensedTrue(licenseState: cachedLicenseState) /// Don't dispatch to main here bc this should already be running on main (?)
        } else {
            updateUI_WithIsLicensedFalse(licenseConfig: cachedLicenseConfig, trialState: cachedTrialState)
        }
        
        /// 2. Get real values and update UI again
//        updateUIToCurrentLicense()
        
    }
    
    /// Did appear
    
    override func viewDidAppear() {
        /// Step 2: Get real values and update UI
        ///     Notes:
        ///         - Why are we doing step 2 in viewDidAppear() and step 1 in viewDidLoad()?
        ///         - viewDidAppear() is called twice upon app launch for some reason (Oct 2024)
        ///             Testing: [Jan 2025] seems like the two calls are a few hundred ms apart, so debouncing is prolly not the best choice?
        
        updateUIToCurrentLicense()
    }
    
    /// Update UI
    
    func updateUIToCurrentLicense() {
            
        /// This is called on load and when the user activates/deactivates their license.
        /// - It would be cleaner and prettier if we used a reactive architecture where you have some global master license state that all the UI that depends on it subscribes to. Buttt we really only have UI that depends on the license state here on the about tab, so that would be overengineering. On the other hand we need to store the AboutTabController instance in MainAppState for global access if we don't use the reactive architecture which is also a little ugly.
        
        
        /// Start an async context
        /// Notes:
        /// - @MainActor so all licensing code runs on the mainthread.
        Task.detached(priority: .userInitiated, operation: { @MainActor in
            
            let licenseState = await GetLicenseState.get()
                
            if licenseState.isLicensed {
                DispatchQueue.main.async { self.updateUI_WithIsLicensedTrue(licenseState: licenseState) } /// Dispatch to main bc UI updates need to run on main.
            } else {
                let licenseConfig = await GetLicenseConfig.get() /// Only get the licenseConfig if the app *is not* licensed - that way, if the app *is* licensed through offline validation, we can avoid all internet connections.
                let trialState = GetTrialState.get(licenseConfig)
                DispatchQueue.main.async { self.updateUI_WithIsLicensedFalse(licenseConfig: licenseConfig, trialState: trialState) }
            }
        })
    }
    
    func updateUI_WithIsLicensedTrue(licenseState: MFLicenseState) {
        
            /// Also see `updateUI_WithIsLicensedFalse()` - the first few lines are logically identical and should be kept in sync
            
            /// Guard: no change from 'current' values
            ///     This prevents unnecessary rerendering of the UI when this function is called several times with the same arguments. (Which we expect to happen - this function is first supposed to be called with cached LicenseState and then with the real LicenseState from the server - as soon as that's available.)
            let isLicensed = true
            if currentIsLicensed == isLicensed &&
               currentLicenseState == licenseState
            {
                return
            }
            
            /// Update 'current' values
            ///     Note: We don't need to copy the values before we store them into the `current...` variables, because they are immutable
            currentIsLicensed = isLicensed
            currentLicenseState = licenseState
            
            /// Deactivate tracking area
            if let trackingArea = self.trackingArea {
                self.view.removeTrackingArea(trackingArea)
            }
            
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
            
            switch licenseState.licenseTypeInfo {
                
            case is MFLicenseTypeInfoFreeCountry:
                
                /// Case: FreeCountry
                
                /// Cast licenseTypeInfo
                guard let info = licenseState.licenseTypeInfo as? MFLicenseTypeInfoFreeCountry else {
                    fatalError("We're in the freeCountry switch case but casting to freeCountry type failed. (That should be impossible.)")
                }
                
                /// Get localized country name + flag emoji
                ///     Note: We only attempt to get the flagEmoji from the regionCode if getting the countryName from the regionCode actually worked. Otherwise flagEmoji getter might perhaps cause buffer overflows and stuff if the regionCode string is garbled up?
                let countryName: String? = Locale.current.localizedString(forRegionCode: info.regionCode)
                let flag: String? = (countryName == nil) ? nil : UIStrings.flagEmoji(info.regionCode)
                
                /// Apply fallbacks
                let countryName_ = countryName ?? "Unknown Country"
                let flag_ = flag ?? "🏁"

                /// Assemble message
                let countryString = String(format: "%@ %@", countryName_, flag_)
                message = String(format: NSLocalizedString("free-country", comment: "First draft: Mac Mouse Fix is currently free in your country (%@)"), countryString)
                
            case is MFLicenseTypeInfoForce:
            
                /// Case: Force
                message = "The app will appear to be licensed due to the FORCE_LICENSED flag"
            
            default:
            
                /// Case: Default
                ///     -> Display 'thankyou for purchasing' message
                
                /// Validate:
                ///     license is one of the standard, personally purchased licenseTypes
                if !MFLicenseTypeIsPersonallyPurchased(licenseState.licenseTypeInfo) {
                    DDLogError("Error: Will display default `thankyou for buying` message on aboutTab but the license is of unexpected (not personally purchased) type \(type(of: licenseState.licenseTypeInfo))")
                    assert(false)
                }
                
                message = Randomizer.select(from: [
                    
                    /// Common
                    (NSLocalizedString("thanks.01", comment: "First draft: ⭐️ Thank you for buying Mac Mouse Fix!"), weight: 1),
                    (NSLocalizedString("thanks.02", comment: "First draft: 🌟 Thanks for purchasing Mac Mouse Fix!"), weight: 1),
                    (NSLocalizedString("thanks.03", comment: "First draft: 🚀 Thanks for supporting Mac Mouse Fix!"), weight: 1),
                    (NSLocalizedString("thanks.04", comment: "First draft: 🙌 Thanks for buying Mac Mouse Fix!"), weight: 1),
                    
                    /// Rare
                    (NSLocalizedString("thanks.05", comment: "First draft: 🧠 Great purchasing decision! ;)"), weight: 0.1),
                    (NSLocalizedString("thanks.06", comment: "First draft: 🔥 Awesome taste in mouse fixing software! ;)"), weight: 0.1),
                    (NSLocalizedString("thanks.07", comment: "First draft: 💙"), weight: 0.1),
                    (NSLocalizedString("thanks.08", comment: "First draft: :) <- My face when I saw you bought Mac Mouse Fix"), weight: 0.1),
                    
                    /// Very rare
                    (NSLocalizedString("thanks.09", comment: "First draft: 👽 Share it with your Spacebook friends!"), weight: 0.05),
                    
                    /// Extremely rare
                    (NSLocalizedString("thanks.10", comment: "First draft: 🏂 Duckgang for life!! || Note: A lot of these are very personal. And weird. They are also super rare. Feel free to change them to anything you feel like to leave a little easter egg!"), weight: 0.01),
                    (NSLocalizedString("thanks.11", comment: "First draft: 🚜 Watch where you're going :P"), weight: 0.01),
                    (NSLocalizedString("thanks.12", comment: "First draft: 🐁 Not these mice, mom!"), weight: 0.01),
                    (NSLocalizedString("thanks.13", comment: "First draft: 🐹 We should get him a bow tie."), weight: 0.01),
                    (NSLocalizedString("thanks.14", comment: "First draft: 🇹🇷 Ey Kanka, tebrikler tebrikler!"), weight: 0.01),
                    (NSLocalizedString("thanks.15", comment: "First draft: 🥛 Whole milk of course! It's your birthday after all."), weight: 0.01),
                    (NSLocalizedString("thanks.16", comment: "First draft: 🎸 Not John Mayer (yet). Nevertheless mayor of hearts."), weight: 0.01),
                    (NSLocalizedString("thanks.17", comment: "First draft: 💃 1NEIN8NEIN"), weight: 0.01),
                    (NSLocalizedString("thanks.18", comment: "First draft: 🦄 You may not want to save the world, but you're already saving mine :)"), weight: 0.01),
                    (NSLocalizedString("thanks.19", comment: "First draft: 🏜️ Dankeschön, meine Frau..."), weight: 0.01),
                    (NSLocalizedString("thanks.20", comment: "First draft: 🌍 Universal Studios is probably not that great anyways... :)"), weight: 0.01),
                    (NSLocalizedString("thanks.21", comment: "First draft: 🐠 What... are... you?"), weight: 0.01),
                    (NSLocalizedString("thanks.22", comment: "First draft: 🖤"), weight: 0.01),
                    (NSLocalizedString("thanks.23", comment: "First draft: 🤍"), weight: 0.01),
                    (NSLocalizedString("thanks.24", comment: "First draft: 😎 Oh you're using Mac Mouse Fix? You must be pretty cool."), weight: 0.01),
                    (NSLocalizedString("thanks.25", comment: "First draft: 🌏 First the mice, then the world!! >:)"), weight: 0.01),
                    
                    /// Mom
                    ("💖❤️❤️❤️ Für Beate :)", weight: 0.005),
                ])
            }
            
            /// Parse markdown in message
            let messageAttributed = NSAttributedString(coolMarkdown: message, fillOutBase: false)!
            
            /// Replace text
            assignAttributedStringKeepingBase(&trialSectionManager!.currentSection.textField!.attributedStringValue, messageAttributed)
            
            /// Remove calendar image
            trialSectionManager!.currentSection.imageView!.image = nil
        
    }
    
    func updateUI_WithIsLicensedFalse(licenseConfig: MFLicenseConfig, trialState: MFTrialState) {
        
            /// Also see `updateUI_WithIsLicensedTrue()` - the first few lines are logically identical and should be kept in sync
            
            /// Guard: no change from 'current' values
            let isLicensed = false
            if currentIsLicensed == isLicensed &&
               currentLicenseConfig == licenseConfig &&
               currentTrialState == trialState
            {
                return
            }
            
            /// Update 'current' values
            ///     Note: We don't need to copy the values before we store them into the `current...` variables, because they are immutable
            currentIsLicensed = isLicensed
            currentLicenseConfig = licenseConfig
            currentTrialState = trialState
            
            /// Deactivate tracking area
            if let trackingArea = self.trackingArea {
                self.view.removeTrackingArea(trackingArea)
            }
            
            ///
            /// Setup trial section
            ///
            
            /// Begin managing
            trialSectionManager?.startManaging(licenseConfig: licenseConfig, trialState: trialState)
            
            /// Set textfield height
            ///     Necessary for y centering. Not sure why
            ///     Edit: Not necessary anymore since we're using the trialSectionManager. Not sure why.
            
    //        trialSectionManager!.trialSection.textField!.heightAnchor.constraint(equalToConstant: 20).isActive = true

            if trialState.trialIsActive {
                
                /// Update layout
                ///     So tracking area frames / bounds are correct
                ///     Update: (Oct 2024) I think we don't need the tracking areas anymore? IIRC they were originally used to change from displaying "Day x/30" to "Click here to Activate License" on hover. But we ended up turning the hover effect off. So I think the tracking areas might not be necessary
                trialSectionManager?.currentSection.needsLayout = true
                trialSectionManager?.currentSection.superview?.needsLayout = true
                trialSectionManager?.currentSection.superview?.layoutSubtreeIfNeeded()
                
                /// Setup tracking area
                trackingArea = NSTrackingArea(rect: trialSectionManager!.currentSection.superview!.bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited], owner: self)
                trialSectionManager!.currentSection.superview!.addTrackingArea(trackingArea!)
                
            }
            else { /// Trial has expired
                
                /// Always show activateLicense button
                trialSectionManager?.showAlternate(animate: false)
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
            
            let payButton = PayButton(title: MFLicenseConfigFormattedPrice(licenseConfig), action: {
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
    
    /// Tracking area calllbacks
    
    override func mouseEntered(with event: NSEvent) {
        
        DispatchQueue.main.async {
            self.trialSectionManager?.showAlternate()
        }
    }
    override func mouseExited(with event: NSEvent) {
        
        DispatchQueue.main.async {
            self.trialSectionManager?.showInitial()
        }
    }
}
