//
// --------------------------------------------------------------------------
// TrialSectionManager.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

class TrialSectionManager {
    
    /// Vars
    
    var trialSection: TrialSection? /// I think this doesn't have to be optional
    
    private var isReplacing = false
    private var isInside = false
    private var queuedReplace: (() -> ())? = nil
    private var ogSection: TrialSection? = nil
    
    
    /// Init
    
    init(_ trialSection: TrialSection, licenseConfig: LicenseConfig, license: MFLicenseReturn) {
        
        /// Store trial section
        self.trialSection = trialSection
        
        /// Set string
        trialSection.textField!.attributedStringValue = LicenseUtility.trialCounterString(licenseConfig: licenseConfig, license: license)
        
        /// Setup image
        if #available(macOS 11.0, *) {
            trialSection.imageView!.symbolConfiguration = .init(pointSize: 13, weight: .regular, scale: .large)
        }
        trialSection.imageView!.image = NSImage(named: "calendar")
    }
    
    /// Interface
    
    func showTrial() {
        
        /// This code is a little convoluted. showTrial and showActivate are almost copy-pasted, except for setting up in newSection in mouseEntered.
        
        DispatchQueue.main.async {
            
            let workload = {
                
                DDLogDebug("triall exit")
                
                if !self.isInside {
                    if let r = self.queuedReplace {
                        self.queuedReplace = nil
                        r()
                    } else {
                        self.isReplacing = false
                    }
                    return
                }
                self.isInside = false
                
                self.isReplacing = true
                
                let ogSection = self.trialSection!
                let newSection = self.ogSection!
                
                ReplaceAnimations.animate(ogView: ogSection, replaceView: newSection, hAnchor: .center, vAnchor: .center, doAnimate: true) {
                    
                    DDLogDebug("triall exit finish")
                    
                    self.trialSection = newSection
                    
                    if let r = self.queuedReplace {
                        self.queuedReplace = nil
                        r()
                    } else {
                        self.isReplacing = false
                    }
                }
            }
            
            if self.isReplacing {
                DDLogDebug("triall queue exit")
                self.queuedReplace = workload
            } else {
                workload()
            }
        }
    }
    
    func showActivate() {
        
        DispatchQueue.main.async {
            
            let workload = {
                
                do {
                    
                    DDLogDebug("triall enter")
                    
                    if self.isInside {
                        if let r = self.queuedReplace {
                            self.queuedReplace = nil
                            r()
                        } else {
                            self.isReplacing = false
                        }
                        return
                    }
                    self.isInside = true
                    
                    self.isReplacing = true
                    
                    let ogSection = self.trialSection!
                    let newSection = try SharedUtilitySwift.insecureCopy(of: self.trialSection!)
                    
                    ///
                    /// Store original trialSection for easy restoration on mouseExit
                    ///
                    
                    if self.ogSection == nil {
                        self.ogSection = try SharedUtilitySwift.insecureCopy(of: self.trialSection!)
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
                    if #available(macOS 11, *) { newSection.imageView?.symbolConfiguration = .init(pointSize: 13, weight: .medium, scale: .large) }
                    if #available(macOS 10.14, *) { newSection.imageView?.contentTintColor = .linkColor }
                    
                    /// Set image
                    newSection.imageView?.image = image
                    
                    /// Setup hyperlink
                    
                    let linkTitle = NSLocalizedString("trial-notif.activate-license-button", comment: "First draft: Activate License")
                    let linkAddress = "https://google.com"
                    let link = Hyperlink(title: linkTitle, url: linkAddress, alwaysTracking: true, leftPadding: 30)
                    link?.font = NSFont.systemFont(ofSize: 13, weight: .regular)
                    
                    link?.translatesAutoresizingMaskIntoConstraints = false
                    link?.heightAnchor.constraint(equalToConstant: link!.fittingSize.height).isActive = true
                    link?.widthAnchor.constraint(equalToConstant: link!.fittingSize.width).isActive = true
                    
                    newSection.textField = link
                    
                    ///
                    /// Done setting up newSection
                    ///
                    
                    ReplaceAnimations.animate(ogView: ogSection, replaceView: newSection, hAnchor: .center, vAnchor: .center, doAnimate: true) {
                        
                        DDLogDebug("triall enter finish")
                        
                        self.trialSection = newSection
                        
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
                DDLogDebug("triall queue enter")
                self.queuedReplace = workload
            } else {
                workload()
            }
            
        }
    }
}
