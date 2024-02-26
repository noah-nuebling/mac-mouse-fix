//
// --------------------------------------------------------------------------
// AppsSwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc class AppUtility: NSObject {
    
    @objc static let shared = AppUtility()
    
    private var runningAppCache: [pid_t: NSRunningApplication] = [:]

    func getRunningAppFast(withPID pid: pid_t) -> NSRunningApplication? {
        
        /// Look up in cache
        /// Notes:
        /// - If this is fast maybe we could reuse this across the app instead of using NSRunningApplication(processIdentifier: pid) directly.
        /// - Should we ever clean up the cache?
        
        if let cachedResult = runningAppCache[pid] {
            return cachedResult
        }
        
        /// Get fresh value, then cache it & return
        if let result = NSRunningApplication(processIdentifier: pid) {
            runningAppCache[pid] = result
            return result
        }
        
        /// Return nil if no running application with the given pid is found
        return nil
    }
    
    @objc func getRunningAppFastForObjc(_ pid: NSNumber) -> NSRunningApplication? {
        /// Notes:
        /// - We need to expose this to objc like this, because it seems if we mark a function @objc which has an arg of type `pid_t`, then the compiler get totally confused and we get cryptic errors.
        return getRunningAppFast(withPID: pid_t(pid.intValue))
    }
}
