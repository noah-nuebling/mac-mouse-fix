//
// --------------------------------------------------------------------------
// LicenseUtility.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

func MFCatch<R, E>(_ workload: () throws(E) -> R) -> (R?, E?) {
    
    /// (Sync version)
    
    /// Explanation:
    ///     Takes a throwing closure `workload` as its argument.
    ///     Runs `workload` and catches any errors it might throw.
    ///     Returns a tuple of the result and the thrown error. Exactly one of the two will be nil.
    ///         (Update: Are we sure? What happens exactly, if the `workload` succeeds but returns nil?)
    ///
    ///     This is very similar to Swift's native `Result` type, but it's simpler, and easier to integrate into our existing completion-handler-based asynchronous code for handling licensing stuff.
    ///         Update: I did have a bit of trouble keeping in mind that exactly one out of `error` and `result` is nil. Maybe using Swift's native `Result` would actually be easier for me... But I don't like the weird switch-case-pattern-matching you have to do there, and it doesn't work with throwing async functions....
    
    var result: R? = nil
    var error: E? = nil
    
    do {
        result = try workload()
    } catch let e {
        error = e
    }
    
    return (result, error)
}

func MFCatch<R, E>(_ workload: () async throws(E) -> R) async -> (R?, E?) {
    
    /// (Async version)
    ///
    /// Explanation:
    ///     This is like the regular MFCatch function, but it works in an async context
    
    var result: R? = nil
    var error: E? = nil
    
    do {
        result = try await workload()
    } catch let e {
        error = e
    }
    
    return (result, error)
}

@objc class LicenseUtility: NSObject { /// [Jun 2025] Not annotating with @MainActor since all the functions here are stateless, 'pure' functions, and annotating with @MainActor makes Swift compiler force us to also annotate other stuff. (See discussion in License/README.md)
    
    @objc static func buyMMF(licenseConfig: MFLicenseConfig, locale: Locale, useQuickLink: Bool) {
        
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
    
    @objc static func trialCounterString(licenseConfig: MFLicenseConfig, trialState: MFTrialState) -> NSAttributedString {
        
        /// Guard unlicensed
        ///     Note: Perhaps we should return an error UI string here, so it is more obvious to the user that sth went wrong and they can file a bug report?
//        assert(!licenseState.isLicensed, "Error: The app is licensed, yet we're trying to display the trialCounterString")
        
        
        /// Get trial state
        ///     Note: We can also get `trialDays` from `trialState` instead of `licenseConfig`, which is sort of redundant
        let trialDays = Int(licenseConfig.trialDays)
        let daysOfUseUI = trialState.daysOfUseUI
        
        /// Build base string
        let base: String
        if !trialState.trialIsActive {
            /// Trial expired
            
            base = NSLocalizedString("trial-counter.expired", comment: "")
            
        } else {
            /// Trial still active
            let b = NSLocalizedString("trial-counter.active", comment: "Note: If you think \"x/y\" looks unnatural in your language you could also use something like \"x of y\"")
            base = String(format: b, daysOfUseUI, trialDays)
        }
        
        /// Apply markdown
        let result = NSAttributedString(coolMarkdown: base)!
        
        /// Return
        return result
        
    }
    
    @objc static func currentRegionCode() -> String? {
        /// Notes:
        /// – Intended behavior: This is supposed to return the system's country code as set in System Settings.
        /// - History of approaches:
        ///     - `Locale.current.language.region?.identifier`, but that gave weird results. E.g. gave China, even though first lang in Preferences was English (US), Region was Germany, and China was only the last language.
        ///     - Then we used `Locale.current.region?.identifier` (and `Locale.current.regionCode` as fallback on older macOS)
        
        /// When testing region and language with Xcode I saw some discrepancies. [Jul 2025]
        ///     I set region to "China mainland" and language to "Chinese (Hong Kong)" on macOS 26 Tahoe Beta 3 and then looked at `Locale.current`
        ///     System Settings:
        ///         `zh_HK@calendar=gregorian;rg=cnzzzz`
        ///             -> .region is CN and .variant is nil
        ///     Xcode:
        ///         `zh-HK_CN`
        ///             -> .region is HK and .variant is CN
        ///     Conclusion:
        ///         Based on this, I'm not 100% sure if the current approach of `Locale.current.region?.identifier` always returns the system's region as set in system settings – which is the intended behavior. We could use the .variant to solve this specific test-case, but I'm not sure if that could introduce other issues. [Jul 2025]
        
        let result: String?
        if #available(macOS 13, *) {
            result = Locale.current.region?.identifier
        } else {
            result = Locale.current.regionCode
        }
        
        DDLogDebug("LicenseUtility.swift: Retrieved regionCode '\(result ?? "(nil)")' from current locale '\(Locale.current)'")
        
        return result
    }
}
