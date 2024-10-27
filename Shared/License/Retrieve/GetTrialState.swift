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
        
#if FORCE_EXPIRED
        let daysOfUse = licenseConfig.trialDays + 1
#elseif FORCE_NOT_EXPIRED
        let daysOfUse = 0
#else
        let daysOfUse = TrialCounter.daysOfUse
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
