//
// --------------------------------------------------------------------------
// TrialSectionManager.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

class TrialSectionManager {
    
    /// Vars
    
    var currentSection: TrialSection
    
    private var initialSection: TrialSection? = nil
    private var shouldShowAlternate = false
    private var queuedReplace: (() -> ())? = nil
    private var animationInterruptor: (() -> ())? = nil
    private var isReplacing = false
    
    /// Init
    
    init(_ initialSection: TrialSection) {
        
        /// Store initialSection
        self.initialSection = initialSection
        
        /// Fill out currentSection with garbage
        self.currentSection = initialSection
    }
    
    /// Start and stop
    
    func startManaging(licenseConfig: LicenseConfig, license: MFLicenseAndTrialState) {
        
        /// Make initialSection current
        showInitial(animate: false)
        
        /// Style intialSection
        
        /// Setup image

        let imageName = license.trialIsActive.boolValue ? "calendar" : "calendar"/*"hourglass.tophalf.filled"*/
        
        if #available(macOS 11.0, *) {
            currentSection.imageView!.symbolConfiguration = .init(pointSize: 13, weight: .regular, scale: .large)
        }
        currentSection.imageView!.image = SFSymbolStrings.image(withSymbolName: imageName)
        
        /// Set string
        currentSection.textField!.attributedStringValue = LicenseUtility.trialCounterString(licenseConfig: licenseConfig, license: license)
        
        /// Set height
        ///     This wasn't necessary under Ventura but under Monterey the textField is too high otherwise
        ///     Edit: The problem is with a linebreak that our custom fallback markdown parser puts at the end! So using coolFittingSize or even fittingSize should be unnecessary.
        if let fittingHeight: CGFloat = currentSection.textField?.coolFittingSize().height {
            currentSection.textField?.heightAnchor.constraint(equalToConstant: fittingHeight).isActive = true
        }
        
    }
    
    func stopManaging() {
        animationInterruptor?()
        showInitial(animate: false)
    }
    
    /// Interface
    
    func showInitial(animate: Bool = true) {
        
        /// This code is a little convoluted. showTrial and showActivate are almost copy-pasted, except for setting up in newSection in mouseEntered.
            
        let workload = {
            
            DDLogDebug("triall enter begin")
            
            if !self.shouldShowAlternate {
                self.finishReplace()
                return
            }
            self.shouldShowAlternate = false
            self.isReplacing = true
            
            let ogSection = self.currentSection
            let newSection = self.initialSection!
            
            assert(self.animationInterruptor == nil)
            
            self.animationInterruptor = ReplaceAnimations.animate(ogView: ogSection, replaceView: newSection, doAnimate: animate) {
                
                DDLogDebug("triall enter finish")
                
                self.animationInterruptor = nil
                
                self.currentSection = newSection
                
                self.finishReplace()
            }
        }
        
        if self.isReplacing {
            DDLogDebug("triall enter queue")
            self.queuedReplace = workload
        } else {
            workload()
        }

    }
    
    func showAlternate(animate: Bool = true) {
        
        let workload = {
            
            do {
                
                DDLogDebug("triall exit begin")
                
                if self.shouldShowAlternate {
                    self.finishReplace()
                    return
                }
                self.shouldShowAlternate = true
                self.isReplacing = true
                
                let ogSection = self.currentSection
                let newSection = try SharedUtilitySwift.insecureDeepCopy(of: self.currentSection)
                
                ///
                /// Store original trialSection for easy restoration on mouseExit
                /// NOTES:
                /// - Why don't we store the initialSection when we start managing?
                /// - Why do we need to make a copy of the currentSection?
                
//                if self.initialSection == nil {
//                    self.initialSection = try SharedUtilitySwift.insecureDeepCopy(of: self.currentSection)
//                }
                
                ///
                /// Setup newSection
                ///
                
                /// Setup Image
                
                /// Create image
                let image = SFSymbolStrings.image(withSymbolName: "lock.open")
                
                /// Configure image
                if #available(macOS 10.14, *) { newSection.imageView?.contentTintColor = .linkColor }
                if #available(macOS 11.0, *) { newSection.imageView?.symbolConfiguration = .init(pointSize: 13, weight: .medium, scale: .large) }
                
                /// Set image
                newSection.imageView?.image = image
                
                /// Setup hyperlink
                
                let linkTitle = NSLocalizedString("trial-notif.activate-license-button", comment: "")
                let link = Hyperlink(title: linkTitle, linkID: kMFLinkIDMMFLActivate, alwaysTracking: true, leftPadding: 30)
                link?.font = NSFont.systemFont(ofSize: 13, weight: .regular)
                
                link?.translatesAutoresizingMaskIntoConstraints = false
                link?.heightAnchor.constraint(equalToConstant: link!.fittingSize.height).isActive = true
                link?.widthAnchor.constraint(equalToConstant: link!.fittingSize.width).isActive = true
                
                newSection.textField = link
                
                ///
                /// Animated replace
                ///
                
                assert(self.animationInterruptor == nil)
                
                self.animationInterruptor = ReplaceAnimations.animate(ogView: ogSection, replaceView: newSection, doAnimate: animate) {
                    
                    DDLogDebug("triall exit finish")
                    
                    self.animationInterruptor = nil
                    
                    self.currentSection = newSection
                    
                    self.finishReplace()
                }
            } catch {
                DDLogError("Failed to swap out trialSection on notification with error: \(error)")
                assert(false)
            }
        }
        
        if self.isReplacing {
            DDLogDebug("triall exit queue")
            self.queuedReplace = workload
        } else {
            workload()
        }
    }
    
    /// Helper
    
    fileprivate func finishReplace() {
        if let r = self.queuedReplace {
            self.queuedReplace = nil
            r()
        } else {
            self.isReplacing = false
        }
    }
}
