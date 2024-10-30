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
    
    @objc static func checkAndReact(triggeredByUser: Bool) {
        
        /// This runs a check and then if necessary it:
        /// - ... shows some feedback about the licensing state to the user
        /// - ... locks down the helper
        
        /// Start an async-context
        ///     Notes:
        ///     - We're using .detached because .init schedules on the current Actor according to the docs. We're not trying to use any Actors.
        Task.detached(priority: (triggeredByUser ? .userInitiated : .background), operation: {
            
            /// Get licensing state
            let (licenseState, trialState) = await checkLicenseAndTrial()
            
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
                        
                        /// Get licenseConfig
                        let licenseConfig = await GetLicenseConfig.get() /// This makes an internet connection, so we wanna avoid calling it unless necessary. Read more in the definition.
                        
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
    
    static func checkLicenseAndTrialOffline() -> (licenseConfig: MFLicenseConfig, licenseState: MFLicenseState, trialState: MFTrialState) {
        
        /// This function retrieves the license-and-trial state of the app without ever making an internet connection
        /// Discussion:
        ///     The 'proper' function' for retrieving the license-and-trial state tries to retrieve the data from the `server`, `cache`, or `fallback`,  while this function will only ever look at the `cache` or `fallback`.
        ///     Because the function never talks to the server, it is guaranteed to return immediately, and it's not marked with `async`
        ///     We made this function so we can immediately render our UIs using probably-correct data upon app-start, without having to wait for the server. Then, when the more-probably-correct data comes in (which might have been retrieved from the server) we update the UIs.
        
        /// Get licenseState from cache / fallback
        let licenseState = GetLicenseState.checkLicenseOffline()
        
        /// Get licenseConfig from cache / fallback
        ///     Discussion: Here we return the `licenseConfig` but in the non-offline sister function `.checkLicenseAndTrial()` we *don't* return `licenseConfig` so that we can avoid retrieving it unless necessary, which lets us minimize the internet connections we make.
        ///              Why not return the cached/fallback version of the licenseConfig in the sister function to avoid internet connections? Because if we always return the cached values they will probably become outdated at some point, which might cause problems - the point of the sister-function is to give us reasonably up-to-date values that we can use long term, while this function here gives us potentially-stale values that we use temporarily while the app starts up. (This is a a bad explanation, I don't fully understand what I'm saying.)
        ///              However, since this method here is expected to return potentially-outdated offline values it seems to make sense to just return the offline licenseConfig for convenience, instead of mirroring the exact return-signature of the non-offline sister function. Yap yap yap I'm bad at writing.
        let licenseConfig = GetLicenseConfig.getOffline()
        
        /// Get trial state using cache / fallback
        ///     Note: I think if `licenseState.isLicensed == true`, then we don't ever wanna look at the trial state. Maybe we should just return trialState == nil in that case?
        ///             ... But on second thought I think that's an unnecessary optimization. Generally, our philosophy on optimization of the UI code is: Don't optimize for performance, ever. It never seems to matter no matter how braindead our algorithms are.
        let trialState = GetTrialState.get(licenseConfig)
        
        /// Return
        return (licenseConfig, licenseState, trialState)
        
    }
    
    @objc static func checkLicenseAndTrial() async -> (licenseState: MFLicenseState, trialState: MFTrialState) {
        
        /// Various notes:
        ///     - Getting the licenseConfig is unnecessary if the app is licensed. That's because all that the licenseState() func needs the licenseConfig for is to check the number of trialDays. And if the app is licensed, we don't need to check for the trialDays.
        
        /// Get licenseState
        let licenseState = await GetLicenseState.checkLicense()
        
        /// Get trialState
        let licenseConfig = await GetLicenseConfig.get()
        let trialState = GetTrialState.get(licenseConfig)
        
        /// Return
        return (licenseState, trialState)
    }
    
    func gumroad_decrementUsageCount(key: String, accessToken: String, completionHandler: @escaping (_ serverResponseDict: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
        
        /// Meant to free a use of the license when the user deactivates it
        /// We won't do this because we'd need to implement oauth and it's not that imporant
        ///    (If we wanted to do this, the API is `/licenses/decrement_uses_count`)
        
        fatalError()
    }
}

