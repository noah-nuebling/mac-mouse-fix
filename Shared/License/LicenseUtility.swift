//
// --------------------------------------------------------------------------
// LicenseUtility.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc class LicenseUtility: NSObject {

    
    @objc static func buyMMF(licenseConfig: LicenseConfig, locale: Locale, useQuickLink: Bool) {
        
        /// Originally implemented this in ObjC but lead to weird linker errors
        
        /// Check if altPayLink country
        let countryCode: String?
        if #available(macOS 13, *) {
            countryCode = locale.region?.identifier
        } else {
            countryCode = locale.regionCode
        }
        
        var isAltCountry = false
        if let countryCode = countryCode {
            isAltCountry = licenseConfig.altPayLinkCountries.contains(countryCode)
        }
        
        /// Get paylink
        var link = ""
        if isAltCountry {
            if useQuickLink  {
                link = licenseConfig.altQuickPayLink
            } else {
                link = licenseConfig.altPayLink
            }
        } else {
            if useQuickLink {
                link = licenseConfig.quickPayLink
            } else {
                link = licenseConfig.payLink
            }
        }
        
        /// Convert to URL
        if let url = URL(string: link) {
                
            /// Open URL
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc static func trialCounterString(licenseConfig: LicenseConfig, license: MFLicenseAndTrialState) -> NSAttributedString {
        
        /// Guard unlicensed
        assert(!license.isLicensed.boolValue)
        
        /// Get trial state
        ///     We can also get `trialDays` from MFLicenseAndTrialState, which is sort of redundant`
        let trialDays = Int(licenseConfig.trialDays)
        let daysOfUse = Int(license.daysOfUseUI)
        
        /// Build base string
        
        let base: String
        if !license.trialIsActive.boolValue {
            /// Trial expired
            
            base = NSLocalizedString("trial-counter.expired", comment: "")
            
        } else {
            /// Trial still active
                
            let b = NSLocalizedString("trial-counter.active", comment: "Note: If you think \"x/y\" looks unnatural in your language you could also use something like \"x of y\"")
            base = String(format: b, daysOfUse, trialDays)
        }
        
        /// Apply markdown
        let result = NSAttributedString(coolMarkdown: base)!
        
        /// Return
        return result
        
    }
    
    @objc static func currentRegionCode() -> String? {
        
        let result: String?
        if #available(macOS 13, *) {
            /// Notes:
            /// - We previously used `Locale.current.language.region?.identifier` here, but that gave weird results. E.g. gave China, even thought first lang in System Preferences was English (US), Region was Germany, and China was only the last language.
            result = Locale.current.region?.identifier
        } else {
            result = Locale.current.regionCode
        }
        
        return result
    }
}
