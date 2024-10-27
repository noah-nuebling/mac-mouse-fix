//
// --------------------------------------------------------------------------
// License.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This is supposed to be a thin wrapper  around `GetLicenseState.swift`, `GetLicenseConfig.swift` and `GetTrialState.swift`.

/// There are some Swift __Active Compilation Conditions__ you can set in the build settings for testing:
/// - `FORCE_EXPIRED` Makes all the trial days be used up
/// - `FORCE_NOT_EXPIRED` Makes the trial days be __not__ used up
/// - `FORCE_LICENSED` Makes the app accept any license key.
/// Note: It seems you need to __clean the build folder__ after changing the flags for them to take effect. (Under Ventura Beta)

/// # __ Problems with the current architecture__ surrounding License.swift
///     We usually want to get both the `MFLicenseConfig` and the `MFLicenseState` together which requires us to make several aynchronous web requests, and we do this over and over, everytime we need the data instead of storing the values
///         We also need to do some manual "hey update yourself since the licensing has changed" calls to keep everything in sync. This also leads us to just reload the about tab whenever it is opened which is kind of unnecessary, and it still breaks when you have the about tab open while the trial expires.
///     -> So here's a __better idea__ for the architecture:
///         There is a currentLicenseState var held by License.swift. It's a reactive signal provider, (That's ReactiveSwift lib lingo, we could also use KVO or Combine) and all the UI that depends on it simply subscribes to it. We init the currentLicenseState to the cache. We update it on app start and when we know it changed due the trial expiring or the user activating their license or something. This should more efficient and much cleaner and should behave better in edge cases. But right now it's not worth implementing because it won't make much of a practical difference to the user.

import Cocoa
import CocoaLumberjackSwift

// MARK: - Main class

@objc class License: NSObject {
    
    // MARK: Lvl 3
    
    @objc static func checkAndReact(licenseConfig: MFLicenseConfig, triggeredByUser: Bool) {
        
        /// This runs a check and then if necessary it:
        /// - ... shows some feedback about the licensing state to the user
        /// - ... locks down the helper
        
        /// Start an async-context
        ///     Notes:
        ///     - We're using .detached because .init schedules on the current Actor according to the docs. We're not trying to use any Actors.
        Task.detached(priority: (triggeredByUser ? .userInitiated : .background), operation: {
            
            /// Get licensing state
            let (licenseState, trialState, _) = await checkLicenseAndTrial(licenseConfig: licenseConfig)
            
            if licenseState.isLicensed {
                
                /// Do nothing if licensed
                return
                
            } else {
                
                /// Not licensed -> check trial
                if trialState.trialIsActive {
                    
                    /// Trial still active -> do nothing
                    //      TODO: @UX Maybe display small reminder after half of trial is over? Or when there's one week of the trial left?
                    
                } else {
                    
                    /// Trial has expired -> show UI
                    
                    if triggeredByUser {
                        
                        /// Display more complex UI
                        ///     This is unused so far
                        
                        /// Validate
                        assert(runningMainApp())
                        
                    } else {
                        
                        /// Not triggered by user -> the users workflow is disruped -> make it as short as possible
                        
                        /// Validate
                        assert(runningHelper())
                        
                        /// Only compile if helper (Otherwise there are linker errors)
                        #if IS_HELPER
                        
                        /// Show trialNotification
                        DispatchQueue.main.async {
                            TrialNotificationController.shared.open(licenseConfig: licenseConfig, licenseState: licenseState, trialState: trialState, triggeredByUser: triggeredByUser)
                        }
                        
                        /// Lock helper
                        SwitchMaster.shared.lockDown()
                        #endif
                        
                    }
                }
            }
        })
    }
    
    // MARK: Lvl 2
    
    /// These functions assemble info about the trial and the license.
    
    static func checkLicenseAndTrialCached(licenseConfig: MFLicenseConfig) -> (licenseState: MFLicenseState, trialState: MFTrialState) {
        
        /// This function only looks at the cache even if there is an internet connection. While this functions sister-function `checkLicenseAndTrial()` retrieves info from the cache only as a fallback if it can't get current info from the internet.
        /// In contrast to the sister function, this function is guaranteed to return immediately since it doesn't load stuff from the internet.
        /// We want this in some places where we need some info immediately to display UI to the user.
        
        /// Get licenseState from cache / fallback
        ///     Note:
        ///         - Here, we we don't throw errors and just silently go to to the fallback if there's no cache, but in the normal (async) `checkLicenseAndTrial()` we do return an error. Does this make sense?
        ///           Update: Yes I think it makes sense: We only use errors to be able to display feedback to the user. This function is meant to get the licenseAndTrialState quickly to render a UI - when we don't have time to wait for a serverResponse. Not a scenario where we'd wanna display errors to the user.
        ///                     Another way to think about it: We only want to inform the user when something goes wrong at the 'source of truth' for the licenseState which is the server. Not if there's some internal issue making the cache invalid.
        let licenseState = GetLicenseState.checkLicenseOffline()
        
        /// Get trial info
        let trialState = GetTrialState.get(licenseConfig)
        
        /// Return
        return (licenseState, trialState)
        
    }
    
    @objc static func checkLicenseAndTrial(licenseConfig: MFLicenseConfig) async -> (licenseState: MFLicenseState, trialState: MFTrialState, error: NSError?) {
        
        /// At the time of writing, we only use licenseConfig to get the maxActivations.
        ///     Since we get licenseConfig via the internet this might be worth rethinking if it's necessary. We made a similar comment somewhere else but I forgot where.
        
        /// Call base functions
        let (licenseState, error) = await GetLicenseState.checkLicense(licenseConfig: licenseConfig)
        let trialState = GetTrialState.get(licenseConfig)
        
        /// Return
        return (licenseState, trialState, error)
    }
    
    func gumroad_decrementUsageCount(key: String, accessToken: String, completionHandler: @escaping (_ serverResponseDict: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
        
        /// Meant to free a use of the license when the user deactivates it
        /// We won't do this because we'd need to implement oauth and it's not that imporant
        ///    (If we wanted to do this, the API is `/licenses/decrement_uses_count`)
        
        fatalError()
    }
}

