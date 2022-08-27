//
// --------------------------------------------------------------------------
// Trial.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class Trial: NSObject {
    
    /// Singleton
    @objc static let shared = Trial()
    
    /// Vars
    private var daily: Timer
    @Atomic private var hasBeenUsedToday: Bool
    private var trialIsActive: Bool
    
    /// Init
    override init() {
        
        /// Garbage init
        daily = Timer()
        hasBeenUsedToday = false
        trialIsActive = false
        
        /// Init super
        super.init()
        
        /// Guard not running helper
        ///     We only want to run the daily timer once, not in both apps
        ///     But we still might want to use this class in main app to access `lastUseDate` and `daysOfUse`.
        ///     Feel like it might be problematic to expose this to mainApp.
        if !SharedUtility.runningHelper() { return }
        
        /// Real init
        
        /// Get licenseConfig
        ///     Note: Getting the licenseConfig is unnecessary if the app is licenseed. That's because all that the licenseState() func needs the licenseConfig for is to check the number of trialDays. And if the app is licensed, we don't need to check for the trialDays.
        
        LicenseConfig.get { licenseConfig in
            
            /// Check licensing state
            License.licenseState(licenseConfig: licenseConfig) { license, error in
                
                if license.state == kMFLicenseStateLicensed {
                    
                    /// Do nothing if licensed
                    
                } else if license.daysOfUse > license.trialDays {
                    
                    /// Not licensed and trial expired -> do nothing
                    ///     Trial expired UI is handeled by Licensing.swift
                    
                } else {
                    
                    /// Trial period is active!
                    
                    /// Set trialActive flag
                    self.trialIsActive = true
                    
                    /// Init hasBeeUsedToday
                    self.hasBeenUsedToday = false
                    if let lastUseDate = Trial.lastUseDate as? NSDate {
                        let now = Date.init(timeIntervalSinceNow: 0)
                        let a = Calendar.current.dateComponents([.day, .month, .year], from: lastUseDate as Date)
                        let b = Calendar.current.dateComponents([.day, .month, .year], from: now)
                        let isSameDay = a.day == b.day && a.month == b.month && a.year == b.year
                        if isSameDay {
                            self.hasBeenUsedToday = true
                        }
                    }
                    
                    /// Init daily timer
                    ///     Notes:
                    ///     - Is fired in 24 hours and then in 24 hour intervals after
                    ///     - Might be smart to fire at 00:00 when the days change? But probably doesn't matter.
                    ///
                    let secondsPerDay = 1*24*60*60
                    self.daily = Timer(timeInterval: TimeInterval(secondsPerDay), repeats: true) { timer in
                        self.hasBeenUsedToday = false
                    }
                    
                    /// Schedule daily timer
                    ///     Not sure if .default or .common is better here. Default might be a little more efficicent but maybe it doesn't work in some cases?
                    RunLoop.main.add(self.daily, forMode: .common)
                }
            }
        }
    }
    
    /// Vars
    ///     Storing the daysOfUse in SecureStorage so it doesn't get reset on uninstall by apps like AppCleaner by Freemacsoft.
    
    @objc static var daysOfUse: Int {
        get {
            SecureStorage.get("License.trial.daysOfUse") as? Int ?? -1
        }
        set {
            SecureStorage.set("License.trial.daysOfUse", value: newValue)
        }
    }
    @objc static var lastUseDate: Date? {
        get {
            config("License.trial.lastUseDate") as? Date
        }
        set {
            setConfig("License.trial.lastUseDate", newValue! as NSObject)
            commitConfig()
        }
    }
    
    /// Interface for Helper
    @objc func handleUse() {
        
        /// Guard not running helper
        assert(SharedUtility.runningHelper())
        
        /// Only react if trial is active
        if !trialIsActive { return }
        
        /// Only react to use once a day
        if hasBeenUsedToday { return }
        
        /// Update state
        hasBeenUsedToday = true
        Trial.lastUseDate = Date(timeIntervalSinceNow: 0)
        Trial.daysOfUse += 1
        
        /// Get updated licenseConfig
        LicenseConfig.get { licenseConfig in
            
            /// Display UI
            License.runCheckAndDisplayUI(licenseConfig: licenseConfig, triggeredByUser: false)
        }
    }
}
