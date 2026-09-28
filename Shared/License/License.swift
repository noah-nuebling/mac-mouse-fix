//
// --------------------------------------------------------------------------
// License.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// @noGCDCleanup Test licensing module now that it's on `licensingRunLoop()`
/// @noGCDCleanup Test on macOS 10.15 (Opus 5.5 isn't sure about SerialExecutor back deployment - but another instance did seem sure - will test anyways before release)
/// @noGCDCleanup All the `await`s can lead to reentrancy bugs. Maybe audit for that.

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

// MARK: - LicensingActor

/// LicensingActor - Swift Concurrency global actor which the Licensing code runs on
///
///     Written by Opus 5.5 [Sep 2026]
///
///     Usage: [Sep 2026] (By Opus 5.5)
///         Only annotate `async` functions and `Task`s with `@LicensingActor` – that's what makes them run on `licensingRunLoop()`, including after each `await`. (Without it, Swift runs `async` functions on its background thread pool.)
///         Don't annotate whole classes or sync functions – sync functions run on their caller's thread anyways, and annotating them makes Swift warn about every caller that's not on LicensingActor (-> `nonisolated` everywhere). We check sync functions with `assertRunLoop()` instead.
///
///     On `priority:`:
///         `priority:` param passed to Task.init() on this Actor is ignored - keeping the params in case we ever re-enable [Sep 2026]

func licensingRunLoop() -> CFRunLoop {
    #if IS_MAIN_APP
        return CFRunLoopGetMain();
    #elseif IS_HELPER
        return GlobalEventTapThread.runLoop();
    #endif
}

@globalActor actor LicensingActor {
    static let shared = LicensingActor()
    private static let executor = _LicensingExecutor()
    nonisolated var unownedExecutor: UnownedSerialExecutor { Self.executor.asUnownedSerialExecutor() }
}

final class _LicensingExecutor: SerialExecutor {
    func enqueue(_ job: UnownedJob) {
        let executor = asUnownedSerialExecutor()
        MFCFRunLoopPerform(licensingRunLoop(), nil) { job.runSynchronously(on: executor) }
    }
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
}

/// Opus 5.5: [Sep 2026] The licensing dataclasses are immutable (all properties are `readonly`), so they're safe to pass between threads.
///     (Needed since the LicensingActor hands them to the mainThread for UI – e.g. `TrialNotificationController`)
extension MFLicenseConfig:  @unchecked Sendable {}
extension MFLicenseState:   @unchecked Sendable {}
extension MFTrialState:     @unchecked Sendable {}

// MARK: - Main class

@objc class License: NSObject {

    // MARK: Lvl 3

    #if IS_HELPER
    @objc static func checkAndReact(triggeredByUser: Bool) {

        /// This runs a check and then if necessary it:
        /// - ... shows some feedback about the licensing state to the user
        /// - ... locks down the helper
        
        /// Start an async-context
        Task.init(priority: (triggeredByUser ? .userInitiated : .background), operation: { @LicensingActor in
            assertRunLoop(licensingRunLoop())

            /// Get licensing state
            let licenseState = await GetLicenseState.get()
            
            if licenseState.isLicensed {
                
                /// Do nothing if licensed
                return
                
            } else {
                
                /// Get stuff
                let licenseConfig = await GetLicenseConfig.get()  /// This makes an internet connection, so we wanna avoid calling it unless necessary. Read more in the definition.
                let trialState = GetTrialState.get(licenseConfig)
                
                /// Not licensed -> check trial
                if trialState.trialIsActive {
                    
                    /// Trial still active -> do nothing
                    //      TODO: @UX Maybe display small reminder after half of trial is over? Or when there's one week of the trial left?
                    
                } else {
                    
                    /// Trial has expired -> show UI
                    
                    if triggeredByUser {
                        
                        /// Display more complex UI
                        ///     This is unused so far
                        ///     Opus 5.5: [Sep 2026] Was meant for the mainApp (used to `assert(runningMainApp())` here), but this function is Helper-only now.
                        assert(false)
                        
                    } else {
                        
                        /// Not triggered by user -> the users workflow is disruped -> make it as short as possible
                        
                        /// Show trialNotification
                        DispatchQueue.main.async {
                            TrialNotificationController.shared.open(licenseConfig: licenseConfig, licenseState: licenseState, trialState: trialState, triggeredByUser: triggeredByUser)
                        }
                        
                        /// Lock helper
                        SwitchMaster.shared.lockDown()
                        
                    }
                }
            }
        })
    }
    #endif

    #if IS_MAIN_APP
    static func checkLicenseAndTrial_Preliminary() -> (licenseConfig: MFLicenseConfig, licenseState: MFLicenseState, trialState: MFTrialState) {

        /// This gets *preliminary* values for the 3 pieces of license-related data we want to share throughout the app:
        ///     `MFLicenseConfig` `MFLicenseState`, and `MFTrialState`
        ///
        /// The preliminary values should be replaced ASAP by properly validated values which can be obtained by the following APIs:
        ///     - `GetLicenseConfig.get()`,
        ///     - `GetLicenseState.get()`
        ///     - `GetTrialState.get(licenseConfig)`
        ///
        /// The advantage of the preliminary values is that we don't need to wait for them. They are guaranteed to be obtained immediately, while the proper values might be obtained through making server connections which we'll have to wait for.
        /// -> The preliminary values can be used to immediately render our UIs upon app startup, without having to wait for a web server's response.
        ///
        /// Sidenote:
        ///     - The preliminary values are obtained and returned from this function all-at-once. For the proper values, they should be obtained only as needed in order to avoid unnecessary internet connections.
        
        assertRunLoop(licensingRunLoop())

        let licenseState = GetLicenseState.get_Preliminary()
        let licenseConfig = GetLicenseConfig.get_Preliminary()
        let trialState = GetTrialState.get(licenseConfig)
        
        return (licenseConfig, licenseState, trialState)
        
    }
    #endif

    #if false
    func gumroad_decrementUsageCount(key: String, accessToken: String, completionHandler: @escaping (_ serverResponseDict: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
        
        /// Meant to free a use of the license when the user deactivates it
        /// We won't do this because we'd need to implement oauth and it's not that imporant
        ///    (If we wanted to do this, the Gumroad API endpoint is `/licenses/decrement_uses_count`)
        
        fatalError()
    }
    #endif
}

