//
// --------------------------------------------------------------------------
// SparkleUpdaterController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import Sparkle

@objc(SparkleUpdaterController)
public class SparkleUpdaterController: NSObject, SUUpdaterDelegate {
    
    private static let CoolSUSkippedMajorVersionKey = "CoolSUSkippedMajorVersion"
    private static let CoolSUSkippedMinorVersionKey = "CoolSUSkippedMinorVersion"
    private static let SUSkippedMinorVersionKey = "SUSkippedVersion"
    
    @objc public static func resetSkippedVersions() {
        /// Delete the users choice about which updates they'd like to skip
        UserDefaults.standard.removeObject(forKey: CoolSUSkippedMinorVersionKey)
        UserDefaults.standard.removeObject(forKey: CoolSUSkippedMajorVersionKey)
    }
    
    private static func getMajorVersion(_ version: String) -> Int {
        if let firstChar = version.first, let val = Int(String(firstChar)) {
            return val
        }
        return 0
    }
    
    @objc public func bestValidUpdate(in appcast: SUAppcast, for updater: SUUpdater) -> SUAppcastItem? {
        let skippedMinorUpdate = UserDefaults.standard.integer(forKey: Self.CoolSUSkippedMinorVersionKey)
        let skippedMajorUpdate = UserDefaults.standard.integer(forKey: Self.CoolSUSkippedMajorVersionKey)
        
        guard let updates = appcast.items as? [SUAppcastItem] else {
            return nil
        }
        
        let currentVersion = Locator.bundleVersionShort() ?? ""
        let currentMajorVersion = Self.getMajorVersion(currentVersion)
        let currentBuildNumber = Locator.bundleVersion()
        
        let comparator = CoolSUComparator()
        
        var minorUpdates: [SUAppcastItem] = []
        var majorUpdates: [SUAppcastItem] = []
        var latestUnshowableUpdate: SUAppcastItem? = nil
        
        for update in updates {
            guard let versionStr = update.versionString, let buildNumber = Int(versionStr) else {
                continue
            }
            let version = update.displayVersionString ?? ""
            let majorVersion = Self.getMajorVersion(version)
            
            if currentBuildNumber >= buildNumber {
                if let currentLatest = latestUnshowableUpdate {
                    let isLater = comparator.compareVersion(version, withBuildNumber: buildNumber as NSNumber,
                                                            toVersion: currentLatest.displayVersionString ?? "", withBuildNumber: (currentLatest.versionString ?? "") as NSObject) == .orderedDescending
                    if isLater {
                        latestUnshowableUpdate = update
                    }
                } else {
                    latestUnshowableUpdate = update
                }
            }
            
            if comparator.compareVersion(currentVersion, withBuildNumber: currentBuildNumber as NSNumber,
                                         toVersion: version, withBuildNumber: buildNumber as NSNumber) != .orderedAscending {
                DDLogDebug("UPDATER: Found OUTDATED update: \(version) (\(buildNumber))")
                continue
            }
            
            if majorVersion == currentMajorVersion {
                DDLogDebug("UPDATER: Found MINOR update: \(version) (\(buildNumber))")
                minorUpdates.append(update)
            } else if majorVersion > currentMajorVersion {
                DDLogDebug("UPDATER: Found MAJOR update: \(version) (\(buildNumber))")
                majorUpdates.append(update)
            } else {
                assertionFailure("This should be filtered out")
            }
        }
        
        var bestMinorUpdate: SUAppcastItem? = nil
        for minorUpdate in minorUpdates {
            if let best = bestMinorUpdate {
                if comparator.compareVersion(best.displayVersionString ?? "", withBuildNumber: (best.versionString ?? "") as NSObject,
                                             toVersion: minorUpdate.displayVersionString ?? "", withBuildNumber: (minorUpdate.versionString ?? "") as NSObject) == .orderedAscending {
                    bestMinorUpdate = minorUpdate
                }
            } else {
                bestMinorUpdate = minorUpdate
            }
        }
        
        var bestMajorUpdate: SUAppcastItem? = nil
        for majorUpdate in majorUpdates {
            if let best = bestMajorUpdate {
                let comparisonResult = comparator.compareVersion(best.displayVersionString, toVersion: majorUpdate.displayVersionString)
                if comparisonResult == .orderedDescending {
                    bestMajorUpdate = majorUpdate
                    continue
                } else if comparisonResult == .orderedAscending {
                    continue
                }
                
                let bestBuild = Int(best.versionString ?? "") ?? 0
                let majorBuild = Int(majorUpdate.versionString ?? "") ?? 0
                if bestBuild < majorBuild {
                    bestMajorUpdate = majorUpdate
                    continue
                }
            } else {
                bestMajorUpdate = majorUpdate
            }
        }
        
        DDLogInfo("UPDATER: bestMajorUpdate: \(bestMajorUpdate?.displayVersionString ?? "") (\(bestMajorUpdate?.versionString ?? "")), bestMinorUpdate: \(bestMinorUpdate?.displayVersionString ?? "") (\(bestMinorUpdate?.versionString ?? "")), latestUnshowableUpdate: \(latestUnshowableUpdate?.displayVersionString ?? "") (\(latestUnshowableUpdate?.versionString ?? "")),\ncurrentVersion: \(currentVersion) (\(currentBuildNumber)),\nskippedMajorUpdate \(skippedMajorUpdate), skippedMinorUpdate \(skippedMinorUpdate)")
        
        var finalMinorUpdate = bestMinorUpdate
        var finalMajorUpdate = bestMajorUpdate
        
        if let minor = finalMinorUpdate, let buildNum = Int(minor.versionString ?? ""), buildNum == skippedMinorUpdate {
            finalMinorUpdate = nil
        }
        if let major = finalMajorUpdate, let buildNum = Int(major.versionString ?? ""), buildNum == skippedMajorUpdate {
            finalMajorUpdate = nil
        }
        
        UserDefaults.standard.removeObject(forKey: Self.SUSkippedMinorVersionKey)
        
        var result: SUAppcastItem? = nil
        if let major = finalMajorUpdate {
            DDLogInfo("UPDATER: Choosing to return bestMajorUpdate to Sparkle")
            result = major
        } else if let minor = finalMinorUpdate {
            DDLogInfo("UPDATER: Choosing to return bestMinorUpdate to Sparkle")
            result = minor
        } else if let unshowable = latestUnshowableUpdate {
            DDLogInfo("UPDATER: Choosing to return latestUnshowableUpdate to Sparkle")
            result = unshowable
        } else {
            DDLogInfo("UPDATER: WARN: Returning empty appcastItem to Sparkle because we couldn't find a latestUnshowableUpdate. This normally shouldn't happen I think, except if the build number of this build is very low.")
            result = SUAppcastItem()
        }
        
        if let res = result {
            let resBuild = Int(res.versionString ?? "") ?? 0
            if resBuild > currentBuildNumber {
                DDLogInfo("UPDATER: Returning update to Sparkle: \(res.displayVersionString ?? "") (\(res.versionString ?? ""))")
            } else {
                DDLogInfo("UPDATER: Returning update to Sparkle: \(res.displayVersionString ?? "") (\(res.versionString ?? "")) - but the build number of the update is not greater than the current build number (\(currentBuildNumber)) so Sparkle 1.27 won't display it.")
            }
        }
        
        return result
    }
    
    @objc public func updater(_ updater: SUUpdater, userDidSkipThisVersion item: SUAppcastItem) {
        DDLogInfo("UPDATER: User skipped version \(item.displayVersionString ?? "")")
        
        let skippedMajorVersion = Self.getMajorVersion(item.displayVersionString ?? "")
        let currentMajorVersion = Self.getMajorVersion(Locator.bundleVersionShort() ?? "")
        
        let isMajorUpdate = skippedMajorVersion > currentMajorVersion
        
        if let buildNum = Int(item.versionString ?? "") {
            if isMajorUpdate {
                UserDefaults.standard.set(buildNum, forKey: Self.CoolSUSkippedMajorVersionKey)
            } else {
                UserDefaults.standard.set(buildNum, forKey: Self.CoolSUSkippedMinorVersionKey)
            }
        }
        
        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: Self.SUSkippedMinorVersionKey)
            updater.checkForUpdatesInBackground()
        }
    }
    
    @objc public func updaterShouldPromptForPermissionToCheck(forUpdates updater: SUUpdater) -> Bool {
        return false
    }
    
    @objc public func updater(_ updater: SUUpdater, willInstallUpdate update: SUAppcastItem) {
        DDLogInfo("UPDATER: About to install update")
    }
    
    @objc public func updaterDidRelaunchApplication(_ updater: SUUpdater) {
        DDLogInfo("UPDATER: App has been launched by Sparkle Updater")
        appState().updaterDidRelaunchApplication = true
        HelperServices.killAllHelpers()
    }
}
