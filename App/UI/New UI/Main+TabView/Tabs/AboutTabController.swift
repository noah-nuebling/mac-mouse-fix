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

    var isLicensed = ConfigValue<Bool>(configPath: "License.isLicensedCache")
    
    @IBOutlet weak var versionField: NSTextField!
    
    @IBOutlet weak var moneyCell: NSView!
    @IBOutlet weak var moneyCellLink: Hyperlink!
    @IBOutlet weak var moneyCellImage: NSImageView!
    
    
    @IBOutlet weak var trialCell: NSView!
    @IBOutlet weak var trialCellText: NSTextField!
    @IBOutlet weak var trialCellImage: NSImageView!
    
    var payButtonwrapperConstraints: [NSLayoutConstraint] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Set up versionField
        
        versionField.stringValue = "\(Utility_App.bundleVersionShort()) (\(Utility_App.bundleVersion()))"
        
        /// Get licensing info
        ///     Not using the completionHandler of `Licensing.licensingState` here since it's asynchronous.
        ///     However, calling `licensingState()` will update isLicensed and then the UI will update
        ///     We could also have separated ConfigValue for the daysOfUse config value, but I don't think it'll be noticable if that doesn't update totally correctly
        Licensing.licensingState(completionHandler: { licensing, error in })
        
        isLicensed.producer.startWithValues { isLicensed in
            
            if isLicensed || true {
                
                ///
                /// Replace trial section with thank you section
                ///
                    
                /// Randomly select 1 out of 25+1 messages
                
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
                    (("🏂", NSLocalizedString("thanks.10", comment: "First draft: Duckgang for life!")), weight: 0.01),
                    (("🚜", NSLocalizedString("thanks.11", comment: "First draft: Watch where you're going :P || Note: In the context of driving a Tractor")), weight: 0.01),
                    (("🐁", NSLocalizedString("thanks.12", comment: "First draft: Not these mice, mom!")), weight: 0.01),
                    (("🐹", NSLocalizedString("thanks.13", comment: "First draft: We should get him a bow tie.")), weight: 0.01),
                    (("🇹🇷", "Ey Kanka, tebrikler tebrikler!"), weight: 0.01),
                    (("🥛", NSLocalizedString("thanks.15", comment: "First draft: Whole milk of course! It's your birthday after all.")), weight: 0.01),
                    (("🎸", NSLocalizedString("thanks.16", comment: "First draft: Not John Mayer. Nonetheless mayor of hearts.")), weight: 0.01),
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
                
                var image = emoji.image(fontSize: 14)
                var r = image.alignmentRect
                image.alignmentRect = NSRect(x: r.minX + (r.maxX - r.midX) - 12, y: r.minY - 1, width: r.width, height: r.height)
                self.trialCellImage.image = image
                
                
            } else /** not licensed */ {
                
                ///
                /// Setup trial section
                ///
                
                /// Set content string
                
                let string = String(format: NSLocalizedString("trial-counter", comment: "First draft: Day **%@/%@** of your test period"), Trial.daysOfUse, Trial.trialDays)
                self.trialCellText.attributedStringValue = NSAttributedString(coolMarkdown: string)!
                
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
                
                let payButton = PayButton()
                payButton.title = "$1.99"
                
                /// Insert payButton into wrapper
                
                let payButtonWrapper = NSView()
                payButtonWrapper.translatesAutoresizingMaskIntoConstraints = false
                payButtonWrapper.wantsLayer = true
                payButtonWrapper.layer?.masksToBounds = false
                
                payButtonWrapper.addSubview(payButton)
                payButtonWrapper.snp.makeConstraints { make in
                    make.top.equalTo(payButton.snp.top)
                    make.centerY.equalTo(payButton.snp.centerY)
                    make.leading.equalTo(payButton.snp.leading)
                }
                
                /// Insert wrapper into UI
                self.payButtonwrapperConstraints = transferSuperViewConstraints(fromView: self.moneyCellLink, toView: payButtonWrapper, transferSizeConstraints: false)
                self.moneyCell.replaceSubview(self.moneyCellLink, with: payButtonWrapper)
                for c in self.payButtonwrapperConstraints {
                    c.isActive = true
                }
                
            }
            
        }
    }
    
    
    
}
