//
// --------------------------------------------------------------------------
// AboutTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class AboutTabController: NSViewController {

//    var isLicensed = ConfigValue<Bool>(configPath: "License.isLicensedCache")
    
    @IBOutlet weak var versionField: NSTextField!
    
    @IBOutlet weak var moneyCell: NSView!
    @IBOutlet weak var moneyCellLink: Hyperlink!
    @IBOutlet weak var moneyCellImage: NSImageView!
    
    @IBOutlet weak var trialCell: NSView!
    @IBOutlet weak var trialCellText: NSTextField!
    @IBOutlet weak var trialCellImage: NSImageView!
    
    var payButtonWrapper: NSView? = nil
    var payButtonwrapperConstraints: [NSLayoutConstraint] = []
    
    var currentLicenseConfig: LicenseConfig? = nil
    var currentLicense: MFLicenseReturn? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Set up versionField
        
        versionField.stringValue = "\(Utility_App.bundleVersionShort()) (\(Utility_App.bundleVersion()))"
        
        /// Get licensing info
        ///     Notes:
        ///     - Not using the completionHandler of `Licensing.licensingState` here since it's asynchronous. However, calling `licensingState()` will update isLicensed and then the UI will update. We could also have separated ConfigValue for the daysOfUse config value, but I don't think it'll be noticable if that doesn't update totally correctl
        
        /// 1. Get cache synchronously and set UI to that
        
        let cachedLicenseConfig = LicenseConfig.getCached()
        let cachedLicense = License.cachedLicenseState(licenseConfig: cachedLicenseConfig)
        
        updateUI(licenseConfig: cachedLicenseConfig, license: cachedLicense)
        
        /// 2. Get real values and update UI again
        
        LicenseConfig.get { licenseConfig in
            License.licenseState(licenseConfig: licenseConfig, completionHandler: { license, error in
                
                self.updateUI(licenseConfig: licenseConfig, license: license)
                
            })
        }
        
    }
    
    func updateUI(licenseConfig: LicenseConfig, license: MFLicenseReturn) {
        
        /// Guard no change
        if currentLicenseConfig?.isEqual(to: licenseConfig) ?? false && currentLicense == license { return }
        currentLicenseConfig = licenseConfig; currentLicense = license
        
        DispatchQueue.main.async {
            /// Dispatch to main, because all the drawing and layout stuff needs to be on main
            
            if license.state == kMFLicenseStateLicensed {
                
                ///
                /// Replace payButton with milkshake link
                ///
                
                /// Note: This only does something if the UI was first updated in the unlicensed state and now it's going back to licensed state. When we hit this straight after loading from IB, the payButtonWrapper will just be nil and the moneyCellLink will be unhidden, so this won't do anything.
                
                self.payButtonWrapper?.isHidden = true
                self.moneyCellLink.isHidden = false
                
                ///
                /// Replace trial section with thank you section
                ///
                
                /// Randomly select 1 out of 25+1 messages
                ///     Note: If you want to test one of the rare ones, increase its `weight`
                
                let (emoji, message) = Randomizer.select(from: [
                    
                    /// Common
                    (("💫", NSLocalizedString("thanks.01", comment: "First draft: Thank you for buying Mac Mouse Fix!")), weight: 1),
                    (("🌟", NSLocalizedString("thanks.02", comment: "First draft: Thanks for purchasing Mac Mouse Fix!")), weight: 1),
                    (("🚀", NSLocalizedString("thanks.03", comment: "First draft: Thanks for supporting Mac Mouse Fix!")), weight: 1),
                    (("🙏", NSLocalizedString("thanks.04", comment: "First draft: Thank you for buying Mac Mouse Fix!")), weight: 1),
                    (("🧠", NSLocalizedString("thanks.05", comment: "First draft: Great purchasing decisions ;)")), weight: 1),
                    
                    /// Rare
                    (("🔥", NSLocalizedString("thanks.06", comment: "First draft: Awesome taste in mouse fixing software ;)")), weight: 0.1),
                    (("💙", ""), weight: 0.1),
                    ((":)", NSLocalizedString("thanks.08", comment: "First draft: <- My face when I saw you bought Mac Mouse Fix")), weight: 0.1),
                    
                    /// Very rare
                    (("👽", NSLocalizedString("thanks.09", comment: "First draft: Share it with your Spacebook friends!")), weight: 0.05),
                    
                    /// Extremely rare
                    (("🏂", NSLocalizedString("thanks.10", comment: "First draft: Duckgang for life! || Note: A lot of these are personal, feel free to change them and leave your own messages!")), weight: 0.01),
                    (("🚜", NSLocalizedString("thanks.11", comment: "First draft: Watch where you're going :P || Note: In the context of driving a Tractor")), weight: 0.01),
                    (("🐁", NSLocalizedString("thanks.12", comment: "First draft: Not these mice, mom!")), weight: 0.01),
                    (("🐹", NSLocalizedString("thanks.13", comment: "First draft: We should get him a bow tie.")), weight: 0.01),
                    (("🇹🇷", "Ey Kanka, tebrikler tebrikler!"), weight: 0.01),
                    (("🥛", NSLocalizedString("thanks.15", comment: "First draft: Whole milk of course! It's your birthday after all.")), weight: 0.01),
                    (("🎸", NSLocalizedString("thanks.16", comment: "First draft: Not John Mayer. Nevertheless mayor of hearts.")), weight: 0.01),
                    (("💃", "1NEIN8NEIN"), weight: 0.01),
                    (("🦋", NSLocalizedString("thanks.18", comment: "First draft: Give me a call when you saved the world. :)")), weight: 0.01),
                    (("🏜️", "Dankeschön, meine Frau..."), weight: 0.01),
                    (("🌍", NSLocalizedString("thanks.20", comment: "First draft: Universal Studios is probably not that great anyways... :)")), weight: 0.01),
                    (("🐠", NSLocalizedString("thanks.21", comment: "First draft: Cuter than a Reaper Leviathan.")), weight: 0.01),
                    (("🖤", ""), weight: 0.01),
                    (("🤍", ""), weight: 0.01),
                    (("😎", NSLocalizedString("thanks.24", comment: "First draft: Oh you're using Mac Mouse Fix? You must be pretty cool.")), weight: 0.01),
                    (("🌏", NSLocalizedString("thanks.25", comment: "First draft: First the mice, then the world!! >:)")), weight: 0.01),
                    //                    (("🤏", "Peepee size of Mac Mouse Fix haters!"), weight: 0.01), /// Too weird
                    
                    /// Mom
                    (("💖❤️❤️❤️", "Für Beate, meine Lieblingsperson :)"), weight: 0.005),
                ])
                
                
                /// Replace text
                self.trialCellText.stringValue = message
                
                /// Replace image
                /// Notes:
                ///     - I think we'd like to have the image view be as tall as the text next to it and then have the image spill out vertically. That's how it works with the sfsymbols next to the links. But idk how to do that. The image always resize everything.
                ///     - Shifting the alignment rect x is a hack. We really want the image and the text to be closer, but we're too lazy to adjust the layoutConstraints from interface builder. Just shifting the alignment x makes everything slighly off center, but I don't think it's noticable. Edit: we turned the alignment x shift off for now, it looks fine.
                
                let image = emoji.image(fontSize: 14)
                let r = image.alignmentRect
                image.alignmentRect = NSRect(x: r.minX + (r.maxX - r.midX) - 12, y: r.minY - 1, width: r.width, height: r.height)
                self.trialCellImage.image = image
                
                
            } else /** not licensed */ {
                
                ///
                /// Setup trial section
                ///
                
                /// Set content string
                
                let string = LicenseUtility.trialCounterString(licenseConfig: licenseConfig, license: license)
                self.trialCellText.attributedStringValue = string
                
                /// Set textfield height
                ///     Necessary for y centering. Not sure why
                
                self.trialCellText.heightAnchor.constraint(equalToConstant: 20).isActive = true
                
                ///
                /// Set up money section
                ///
                
                /// Swap out milkshake -> shopping bag
                ///     Don't know how to set scale pre macOS 11.0 Big Sur. So it'll just look a little crappy.
                
                self.moneyCellImage.imageScaling = .scaleNone
                if #available(macOS 11.0, *) {
                    self.moneyCellImage.symbolConfiguration = .init(scale: .large)
                }
                self.moneyCellImage.image = NSImage(named: .init("bag"))
                
                /// Swap out link -> payButton
                
                /// Create paybutton
                
                let payButton = PayButton(title: licenseConfig.formattedPrice) {
                    guard let url = URL(string: licenseConfig.quickPayLink) else { return }
                    NSWorkspace.shared.open(url)
                }
                
                /// Insert payButton into wrapper
                
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
    }
    
}
