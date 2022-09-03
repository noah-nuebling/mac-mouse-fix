//
// --------------------------------------------------------------------------
// LicenseUtility.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class LicenseUtility: NSObject {

    
    @objc static func trialCounterString(licenseConfig: LicenseConfig, license: MFLicenseReturn) -> NSAttributedString {
        
        /// Guard unlicensed
        assert(license.state == kMFLicenseStateUnlicensed)
        
        /// Get trial state
        ///     We can also get `trialDays` from MFLicenseReturn, which is sort of redundant`
        let trialDays = Int(licenseConfig.trialDays)
        let daysOfUse = Int(license.daysOfUse)
        
        /// Build base string
        
        let base: String
        if !license.trialIsActive.boolValue {
            /// Trial expired
            
            base = NSLocalizedString("trial-counter.expired", comment: "First draft: Free days **used up**")
            
        } else {
            /// Trial still active
                
            let b = NSLocalizedString("trial-counter.active", comment: "First draft: Free day **%d/%d**")
            base = String(format: b, daysOfUse, trialDays)
        }
        
        /// Apply markdown
        let result = NSAttributedString(coolMarkdown: base)!
        
        /// Return
        return result
        
    }
}
