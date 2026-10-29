//
// --------------------------------------------------------------------------
// TrialState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

@objc class GetTrialState : NSObject {
    
    /// -> This class retrieves instances of the `MFTrialState` dataclass

    @objc static func get(_ licenseConfig: MFLicenseConfig) -> MFTrialState {
        assertRunLoop(licensingRunLoop())


        var daysOfUse = 0
        #if FORCE_EXPIRED
            daysOfUse = licenseConfig.trialDays + 1
        #elseif FORCE_NOT_EXPIRED
            daysOfUse = 0
        #else
            /// Note on reading secureStorage separately from `GetLicenseState.get()`: [Oct 2026]
            ///     Callers call `GetLicenseState.get()` and `GetTrialState.get()` in quick succession, both read `secureStorage` separately.
            ///     The two reads can disagree if the keychain fails sporadically (there are network `await`s between them).
            ///     Ideally, we'd read the keychain once and then pass the values through.
            ///     Currently [Oct 2026] this very unlikely to cause issues, since a failed license read won't invalidate the offline license (`licenseStateCache`), and a failed trial read is covered by `kDaysOfUseFallback`.
            ///     Also see 'Free days are over' bug notes
            var secureStorage: NSMutableDictionary? = nil
            let _: SecureStorageReadError = readSecureStorage(/*callerName*/"GetTrialState.get", &secureStorage)
            daysOfUse = secureStorage?.object(forCoolKeyPath: "License.trial.daysOfUse") as? Int ?? kDaysOfUseFallback /// No need to check the `SecureStorageReadError`. See `kDaysOfUseFallback`
        #endif
        
        let trialDays = licenseConfig.trialDays
        let trialIsActive = daysOfUse <= trialDays
        let daysOfUseUI = SharedUtilitySwift.clip(daysOfUse, betweenLow: 1, high: trialDays)
        
        let result = MFTrialState(
            daysOfUse: daysOfUse,
            daysOfUseUI: daysOfUseUI,
            trialDays: trialDays,
            trialIsActive: trialIsActive
        )
        
        return result
    }

}
