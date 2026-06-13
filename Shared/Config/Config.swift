//
// --------------------------------------------------------------------------
// Config.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

#if IS_HELPER
import Cocoa
#endif

@objc(Config)
public class Config: NSObject {
    
    @objc public static let shared: Config = _instance
    private static let _instance: Config = Config()
    
    @objc public var config: NSMutableDictionary = NSMutableDictionary()
    @objc public var configWithAppOverridesApplied: NSMutableDictionary?
    
    private var configFilePath: String
    private var bundleIDOfAppWhichCausesAppOverride: String?
    private var lastLogTime: TimeInterval = 0
    
    private static var _uiAppOverrideBundleID: String?
    
    @objc public static func setUIAppOverrideBundleID(_ bundleID: String?) {
        _uiAppOverrideBundleID = bundleID
    }
    
    @objc public static func uiAppOverrideBundleID() -> String? {
        return _uiAppOverrideBundleID
    }
    
    @objc public static func appOverrideIdentifierForRunningApplication(_ application: NSRunningApplication?) -> String? {
        guard let application = application else { return nil }
        
        if let bundleID = application.bundleIdentifier, !bundleID.isEmpty {
            if bundleID.hasPrefix("com.apple.Safari.WebApp.") {
                return "com.apple.Safari"
            }
            if bundleID.hasPrefix("com.google.Chrome.app.") {
                return "com.google.Chrome"
            }
            if bundleID.hasPrefix("com.microsoft.edgemac.app.") {
                return "com.microsoft.edgemac"
            }
            if bundleID.hasPrefix("com.brave.Browser.app.") {
                return "com.brave.Browser"
            }
            return bundleID
        }
        
        if let bundlePath = application.bundleURL?.path, !bundlePath.isEmpty {
            return "path:" + URL(fileURLWithPath: bundlePath).standardized.path
        }
        
        return nil
    }
    
    @objc public static func load_Manual() {
        _ = shared
        loadFileAndUpdateStates()
        #if IS_HELPER
        shared.setupFSEventStreamCallback()
        #endif
    }
    
    override init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let relativePath = "\(kMFBundleIDApp)/config.plist"
        self.configFilePath = appSupport.appendingPathComponent(relativePath).path
        super.init()
    }
    
    @objc public static func configForKeyPath(_ keyPath: String) -> NSObject? {
        var configDict = shared.config
        #if IS_MAIN_APP
        if let uiAppOverrideBundleID = _uiAppOverrideBundleID,
           !keyPath.hasPrefix("State"),
           !keyPath.hasPrefix("Constants"),
           !keyPath.hasPrefix("AppOverrides") {
            let escapedBundleID = uiAppOverrideBundleID.replacingOccurrences(of: ".", with: "\\.")
            let overrideKeyPath = "AppOverrides.\(escapedBundleID).Root.\(keyPath)"
            if let overrideValue = configDict.object(forCoolKeyPath: overrideKeyPath) as? NSObject {
                return overrideValue
            }
        }
        #endif
        #if IS_HELPER
        if let configDictWithAppOverridesApplied = shared.configWithAppOverridesApplied {
            configDict = configDictWithAppOverridesApplied
        }
        #endif
        return configDict.object(forCoolKeyPath: keyPath) as? NSObject
    }
    
    @objc public static func setConfigValue(_ value: NSObject, forKeyPath keyPath: String) {
        #if DEBUG
        if shared.config.object(forCoolKeyPath: keyPath) == nil {
            DDLogDebug("Setting value \(value) to config at non-existent keyPath \(keyPath). The keypath will be created.")
        }
        #endif
        #if IS_MAIN_APP
        if let uiAppOverrideBundleID = _uiAppOverrideBundleID,
           !keyPath.hasPrefix("State"),
           !keyPath.hasPrefix("Constants"),
           !keyPath.hasPrefix("AppOverrides") {
            let escapedBundleID = uiAppOverrideBundleID.replacingOccurrences(of: ".", with: "\\.")
            let overrideKeyPath = "AppOverrides.\(escapedBundleID).Root.\(keyPath)"
            shared.config.setObject(value, forCoolKeyPath: overrideKeyPath)
            return
        }
        #endif
        shared.config.setObject(value, forCoolKeyPath: keyPath)
    }
    
    @objc public static func removeFromConfigForKeyPath(_ keyPath: String) {
        shared.config.removeObject(forCoolKeyPath: keyPath)
    }
    
    private static func defaultConfigURL() -> URL {
        let defaultConfigPathRelative = "Contents/Resources/default_config.plist"
        return Locator.mainAppBundle().bundleURL.appendingPathComponent(defaultConfigPathRelative)
    }
    
    @objc public static func commitConfig() {
        assert(Thread.isMainThread)
        shared.writeConfigToFile()
        MFMessagePort.sendMessage("configFileChanged", withPayload: nil, waitForReply: false)
        updateDerivedStates()
    }
    
    @objc public static func loadFileAndUpdateStates() {
        shared.loadConfigFromFile()
        updateDerivedStates()
    }
    
    @objc public static func updateDerivedStates() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                updateDerivedStates()
            }
            return
        }
        
        #if IS_MAIN_APP
        ReactiveConfig.shared.react(newConfig: shared.config)
        #endif
        
        #if IS_HELPER
        let currentAppIdentifier = shared.bundleIDOfAppWhichCausesAppOverride ?? ""
        _ = shared.loadOverridesForApp(currentAppIdentifier, force: true)
        
        Remap.reload()
        ScrollConfig.reload()
        PointerConfig.reload()
        GeneralConfig.reload()
        MenuBarItem.reload()
        #endif
    }
    
    #if IS_HELPER
    @objc public func loadOverridesForAppUnderMousePointerWithEvent(_ event: CGEvent) -> Bool {
        assert(runningHelper())
        
        guard let app = HelperUtility.appUnderMousePointer(with: event) else { return false }
        let appIdentifier = Config.appOverrideIdentifierForRunningApplication(app) ?? ""
        
        let currentTime = ProcessInfo.processInfo.systemUptime
        if currentTime - self.lastLogTime > 0.5 {
            DDLogInfo("[Config.swift] appUnderPointer PID: \(app.processIdentifier), appIdentifier: '\(appIdentifier)', prev: '\(self.bundleIDOfAppWhichCausesAppOverride ?? "")'")
            self.lastLogTime = currentTime
        }
        
        if self.bundleIDOfAppWhichCausesAppOverride != appIdentifier {
            DDLogInfo("[Config.swift] Overrides changing from '\(self.bundleIDOfAppWhichCausesAppOverride ?? "")' to '\(appIdentifier)'")
            return self.loadOverridesForApp(appIdentifier)
        }
        
        return false
    }
    
    @objc public func loadOverridesForApp(_ appIdentifier: String) -> Bool {
        return loadOverridesForApp(appIdentifier, force: false)
    }
    
    @objc(loadOverridesForApp:force:)
    public func loadOverridesForApp(_ appIdentifier: String, force: Bool) -> Bool {
        assert(runningHelper())
        
        if !force && self.bundleIDOfAppWhichCausesAppOverride == appIdentifier {
            return false
        }
        self.bundleIDOfAppWhichCausesAppOverride = appIdentifier
        
        guard let overrides = self.config.object(forKey: kMFConfigKeyAppOverrides) as? NSDictionary else {
            self.configWithAppOverridesApplied = (self.config.mutableCopy() as! NSMutableDictionary)
            return true
        }
        
        var overridesForThisApp: NSDictionary?
        for key in overrides.allKeys {
            if let keyStr = key as? String, keyStr == appIdentifier {
                if let appDict = overrides.object(forKey: keyStr) as? NSDictionary {
                    overridesForThisApp = appDict.object(forKey: "Root") as? NSDictionary
                }
                break
            }
        }
        
        if let overridesForThisApp = overridesForThisApp {
            if let applied = SharedUtility.dictionaryWithOverridesApplied(from: overridesForThisApp as! [AnyHashable : Any], to: self.config as! [AnyHashable : Any]) as NSDictionary? {
                self.configWithAppOverridesApplied = (applied.mutableCopy() as! NSMutableDictionary)
            } else {
                self.configWithAppOverridesApplied = (self.config.mutableCopy() as! NSMutableDictionary)
            }
        } else {
            self.configWithAppOverridesApplied = (self.config.mutableCopy() as! NSMutableDictionary)
        }
        
        return true
    }
    #endif
    
    #if IS_HELPER
    private func setupFSEventStreamCallback() {
        // Unused in MMF 3.
    }
    #endif
    
    private func writeConfigToFile() {
        if runningPreRelease() {
            let isValid = CFPropertyListIsValid(config, .xmlFormat_v1_0)
            assert(isValid)
        }
        
        do {
            let configData = try PropertyListSerialization.data(fromPropertyList: config, format: .xml, options: 0)
            try configData.write(to: Locator.configURL, options: .atomic)
            DDLogInfo("Wrote config to file.")
        } catch {
            DDLogInfo("ERROR writing config to file: \(error)")
        }
    }
    
    private static func _readDictPlist(url: URL, mutable: Bool) throws -> NSMutableDictionary {
        let data = try Data(contentsOf: url)
        var format: PropertyListSerialization.PropertyListFormat = .xml
        let plist = try PropertyListSerialization.propertyList(from: data, options: mutable ? [.mutableContainersAndLeaves] : [], format: &format)
        guard let dict = plist as? NSMutableDictionary else {
            throw NSError(domain: NSCocoaErrorDomain, code: 3840, userInfo: [NSLocalizedDescriptionKey: "Deserialized plist is not a dictionary"])
        }
        return dict
    }
    
    @objc public func loadConfigFromFile() {
        #if IS_MAIN_APP
        _loadAndRepair()
        #else
        do {
            self.config = try Config._readDictPlist(url: Locator.configURL, mutable: true)
        } catch {
            DDLogError("Failed to read config file with error: \(error)")
            fatalError("Failed to read config file: \(error)")
        }
        #endif
        
        DDLogDebug("Loaded config from file: \(self.config)")
    }
    
    private func _loadAndRepair() {
        assert(runningMainApp())
        assert(Thread.isMainThread)
        
        var err: NSError?
        
        // Load default config
        var defaultConfig: NSMutableDictionary
        do {
            defaultConfig = try Config._readDictPlist(url: Config.defaultConfigURL(), mutable: true)
        } catch {
            DDLogError("Loading defaultConfig failed with error: \(error)")
            fatalError("Loading defaultConfig failed: \(error)")
        }
        
        // Load local config
        do {
            self.config = try Config._readDictPlist(url: Locator.configURL, mutable: true)
        } catch {
            let nsErr = error as NSError
            if nsErr.domain == NSCocoaErrorDomain && nsErr.code == NSFileReadNoSuchFileError {
                DDLogInfo("Config file doesn't exist. Creating a new one.")
                do {
                    try FileManager.default.createDirectory(at: Locator.configURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    replace(with: defaultConfig)
                    repairContaminatedOverrides()
                    return
                } catch {
                    DDLogError("Creating directory for config failed: \(error)")
                    fatalError("Creating directory for config failed: \(error)")
                }
            } else {
                DDLogError("Loading config failed with error: \(error)")
                fatalError("Loading config failed: \(error)")
            }
        }
        
        // Check version
        guard let currentVersionNS = self.config.object(forCoolKeyPath: "Constants.configVersion") as? NSNumber,
              let targetVersionNS = defaultConfig.object(forCoolKeyPath: "Constants.configVersion") as? NSNumber else {
            DDLogError("Version fields missing. Replacing config...")
            replace(with: defaultConfig)
            repairContaminatedOverrides()
            return
        }
        
        var currentVersion = currentVersionNS.intValue
        let targetVersion = targetVersionNS.intValue
        
        if currentVersion == targetVersion {
            DDLogInfo("configVersion matches (\(currentVersion)) We can keep using the existing config...")
            repairContaminatedOverrides()
            return
        } else if currentVersion > targetVersion {
            DDLogInfo("configVersion decreased from \(currentVersion) to \(targetVersion). Not repairing downgrades...")
            replace(with: defaultConfig)
            repairContaminatedOverrides()
            return
        } else {
            DDLogInfo("configVersion increased from \(currentVersion) to \(targetVersion). Trying to repair...")
            while true {
                if currentVersion == 21 {
                    DDLogInfo("Upgrading configVersion from 21 to 22...")
                    let d = Config.configForKeyPath("License.trial.lastUseDate")
                    SecureStorage.set("License.trial.lastUseDate", value: d)
                    Config.removeFromConfigForKeyPath("License.trial.lastUseDate")
                    currentVersion = 22
                } else if currentVersion == 22 {
                    DDLogInfo("Upgrading configVersion from 22 to 23...")
                    let d = defaultConfig.object(forCoolKeyPath: "Constants.defaultRemaps.threeButtons") as? NSObject
                    Config.setConfigValue(d ?? NSObject(), forKeyPath: "Constants.defaultRemaps.threeButtons")
                    currentVersion = 23
                } else if currentVersion == 23 {
                    DDLogInfo("Upgrading configVersion from 23 to 24...")
                    Config.removeFromConfigForKeyPath("License.isLicensedCache")
                    Config.removeFromConfigForKeyPath("License.licenseReasonCache")
                    currentVersion = 24
                } else {
                    DDLogInfo("No upgrades from configVersion \(currentVersion). Target is \(targetVersion).")
                    replace(with: defaultConfig)
                    repairContaminatedOverrides()
                    return
                }
                
                if currentVersion == targetVersion {
                    DDLogInfo("Config was repaired! It was upgraded to configVersion \(currentVersion).")
                    Config.setConfigValue(NSNumber(value: targetVersion), forKeyPath: "Constants.configVersion")
                    Config.commitConfig()
                    repairContaminatedOverrides()
                    return
                }
            }
        }
    }
    
    private func replace(with defaultConfig: NSMutableDictionary) {
        DDLogInfo("Replacing config with default config...")
        self.config = defaultConfig
        Config.commitConfig()
    }
    
    private func repairContaminatedOverrides() {
        guard let appOverrides = self.config[kMFConfigKeyAppOverrides] as? NSMutableDictionary else { return }
        var didChange = false
        
        for appKey in appOverrides.allKeys {
            guard let appKeyStr = appKey as? String,
                  let appDict = appOverrides[appKeyStr] as? NSMutableDictionary,
                  let rootDict = appDict["Root"] as? NSMutableDictionary else { continue }
            
            if let nestedOverrides = rootDict["AppOverrides"] as? NSDictionary {
                didChange = true
                for nestedKey in nestedOverrides.allKeys {
                    if appOverrides[nestedKey] == nil {
                        appOverrides[nestedKey] = nestedOverrides[nestedKey]
                    }
                }
                rootDict.removeObject(forKey: "AppOverrides")
                
                if appDict is NSMutableDictionary {
                    appDict["Root"] = rootDict
                } else {
                    let mutableAppDict = appDict.mutableCopy() as! NSMutableDictionary
                    mutableAppDict["Root"] = rootDict
                    appOverrides[appKeyStr] = mutableAppDict
                }
            }
        }
        
        if didChange {
            DDLogInfo("Config.swift: Repaired contaminated (nested) AppOverrides in config.plist")
            Config.commitConfig()
        }
    }
    
    @objc public func repairIncompleteAppOverrideForBundleID(_ bundleID: String, relevantKeyPaths keyPathsToDefaultValues: [String]) {
        assertionFailure("repairIncompleteAppOverrideForBundleID is untested and unused.")
        
        DDLogInfo("Repairing incomplete appOverrides...")
        let bundleIDEscaped = bundleID.replacingOccurrences(of: ".", with: "\\.")
        for defaultKP in keyPathsToDefaultValues {
            let overrideKP = "AppOverrides.\(bundleIDEscaped).Root.\(defaultKP)"
            if self.config.object(forCoolKeyPath: overrideKP) == nil {
                self.config.setObject(self.config.object(forCoolKeyPath: defaultKP) ?? NSObject(), forCoolKeyPath: overrideKP)
            }
        }
        Config.commitConfig()
    }
    
    @objc public func cleanConfig() {
        if let appOverrides = self.config[kMFConfigKeyAppOverrides] as? NSMutableDictionary {
            Config.removeLeaflessSubDicts(appOverrides)
        }
        Config.commitConfig()
    }
    
    private static func removeLeaflessSubDicts(_ dict: NSMutableDictionary) {
        for key in dict.allKeys {
            if let subDict = dict[key] as? NSMutableDictionary {
                removeLeaflessSubDicts(subDict)
                if subDict.count == 0 {
                    dict.removeObject(forKey: key)
                }
            }
        }
    }
}
