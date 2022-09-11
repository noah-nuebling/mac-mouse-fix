//
// --------------------------------------------------------------------------
// TrialSectionManager.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

class TrialSectionManager {
    
    /// Vars
    
    var currentSection: TrialSection
    
    private var isReplacing = false
    private var shouldShowActivate = false
    private var queuedReplace: (() -> ())? = nil
    private var initialSection: TrialSection? = nil
    private var animationInterruptor: (() -> ())? = nil
    
    /// Init
    
    init(_ trialSection: TrialSection) {
        
        /// Store trial section
        self.currentSection = trialSection
    }
    
    /// Start and stop
    
    func startManaging(licenseConfig: LicenseConfig, license: MFLicenseReturn) {
        
        /// Init trial section
        
        /// Setup image

        let imageName = license.trialIsActive.boolValue ? "calendar" : "calendar"/*"hourglass.tophalf.filled"*/
        
        if #available(macOS 11.0, *) {
            currentSection.imageView!.symbolConfiguration = .init(pointSize: 13, weight: .regular, scale: .large)
        }
        currentSection.imageView!.image = NSImage(named: imageName)
        
        /// Set string
        currentSection.textField!.attributedStringValue = LicenseUtility.trialCounterString(licenseConfig: licenseConfig, license: license)
    }
    
    func stopManaging() {
        animationInterruptor?()
        showTrial(animate: false)
    }
    
    /// Interface
    
    func showTrial(animate: Bool = true) {
        
        /// This code is a little convoluted. showTrial and showActivate are almost copy-pasted, except for setting up in newSection in mouseEntered.
            
        let workload = {
            
            DDLogDebug("triall enter begin")
            
            if !self.shouldShowActivate {
                if let r = self.queuedReplace {
                    self.queuedReplace = nil
                    r()
                } else {
                    self.isReplacing = false
                }
                return
            }
            self.shouldShowActivate = false
            
            self.isReplacing = true
            
            let ogSection = self.currentSection
            let newSection = self.initialSection!
            
            assert(self.animationInterruptor == nil)
            
            self.animationInterruptor = ReplaceAnimations.animate(ogView: ogSection, replaceView: newSection, doAnimate: animate) {
                
                DDLogDebug("triall enter finish")
                
                self.animationInterruptor = nil
                
                self.currentSection = newSection
                
                if let r = self.queuedReplace {
                    self.queuedReplace = nil
                    r()
                } else {
                    self.isReplacing = false
                }
            }
        }
        
        if self.isReplacing {
            DDLogDebug("triall enter queue")
            self.queuedReplace = workload
        } else {
            workload()
        }

    }
    
    func showActivate() {
        
        let workload = {
            
            do {
                
                DDLogDebug("triall exit begin")
                
                if self.shouldShowActivate {
                    if let r = self.queuedReplace {
                        self.queuedReplace = nil
                        r()
                    } else {
                        self.isReplacing = false
                    }
                    return
                }
                self.shouldShowActivate = true
                
                self.isReplacing = true
                
                let ogSection = self.currentSection
                let newSection = try SharedUtilitySwift.insecureCopy(of: self.currentSection)
                
                ///
                /// Store original trialSection for easy restoration on mouseExit
                ///
                
                if self.initialSection == nil {
                    self.initialSection = try SharedUtilitySwift.insecureCopy(of: self.currentSection)
                }
                
                ///
                /// Setup newSection
                ///
                
                /// Setup Image
                
                /// Create image
                let image: NSImage
                if #available(macOS 11.0, *) {
                    image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: nil)!
                } else {
                    image = NSImage(named: "lock.open")!
                }
                
                /// Configure image
                if #available(macOS 11.0, *) { newSection.imageView?.symbolConfiguration = .init(pointSize: 13, weight: .medium, scale: .large) }
                if #available(macOS 10.14, *) { newSection.imageView?.contentTintColor = .linkColor }
                
                /// Set image
                newSection.imageView?.image = image
                
                /// Setup hyperlink
                
                let linkTitle = NSLocalizedString("trial-notif.activate-license-button", comment: "First draft: Activate License")
                let linkAddress = "macmousefix:activate"
                let link = Hyperlink(title: linkTitle, url: linkAddress, alwaysTracking: true, leftPadding: 30)
                link?.font = NSFont.systemFont(ofSize: 13, weight: .regular)
                
                link?.translatesAutoresizingMaskIntoConstraints = false
                link?.heightAnchor.constraint(equalToConstant: link!.fittingSize.height).isActive = true
                link?.widthAnchor.constraint(equalToConstant: link!.fittingSize.width).isActive = true
                
                newSection.textField = link
                
                ///
                /// Done setting up newSection
                ///
                
                assert(self.animationInterruptor == nil)
                
                self.animationInterruptor = ReplaceAnimations.animate(ogView: ogSection, replaceView: newSection) {
                    
                    DDLogDebug("triall exit finish")
                    
                    self.animationInterruptor = nil
                    
                    self.currentSection = newSection
                    
                    if let r = self.queuedReplace {
                        self.queuedReplace = nil
                        r()
                    } else {
                        self.isReplacing = false
                    }
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
}
