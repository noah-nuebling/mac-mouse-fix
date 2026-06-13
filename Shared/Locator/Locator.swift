//
// --------------------------------------------------------------------------
// Locator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc(Locator)
public class Locator: NSObject {
    
    @objc public static func bundleVersion() -> Int {
        return (mainAppBundle().object(forInfoDictionaryKey: "CFBundleVersion") as? String).flatMap(Int.init) ?? 0
    }
    
    @objc public static func bundleVersionShort() -> String? {
        return mainAppBundle().object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    
    @objc public static func helperBundle() -> Bundle {
        if runningHelper() {
            return Bundle.main
        }
        var main: Bundle?
        var helper: Bundle?
        getBundlesForMainApp(&main, helper: &helper)
        assert(helper != nil)
        return helper!
    }
    
    @objc public static func mainAppBundle() -> Bundle {
        if runningMainApp() {
            return Bundle.main
        }
        var main: Bundle?
        var helper: Bundle?
        getBundlesForMainApp(&main, helper: &helper)
        assert(main != nil)
        return main!
    }
    
    @objc public static func helperOriginalBundle() -> Bundle? {
        var main: Bundle?
        var helper: Bundle?
        getOriginalBundlesForMainApp(&main, helper: &helper)
        return helper
    }
    
    @objc public static func mainAppOriginalBundle() -> Bundle? {
        var main: Bundle?
        var helper: Bundle?
        getOriginalBundlesForMainApp(&main, helper: &helper)
        return main
    }
    
    @objc public static func currentExecutableURL() -> URL {
        return URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
    }
    
    @objc public static var MFApplicationSupportFolderURL: URL {
        return sMFApplicationSupportFolderURL
    }
    
    @objc public static var configURL: URL {
        return sConfigURL
    }
    
    @objc public static func launchdPlistURL() -> URL? {
        let launchdPlistRelativePathFromLibrary = "LaunchAgents/\(kMFBundleIDHelper).plist"
        guard let userLibURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        return userLibURL.appendingPathComponent(launchdPlistRelativePathFromLibrary)
    }
    
    @objc public static func defaults() -> UserDefaults? {
        /// Use config instead of defaults. There's no good reason to use defaults.
        assertionFailure("Use config instead of defaults.")
        if runningMainApp() {
            return UserDefaults.standard
        } else if runningHelper() {
            return UserDefaults(suiteName: kMFBundleIDApp)
        } else {
            exit(1)
        }
    }
    
    private static let sMFApplicationSupportFolderURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(kMFBundleIDApp)
    }()
    
    private static let sConfigURL: URL = {
        return sMFApplicationSupportFolderURL.appendingPathComponent("config.plist")
    }()
    
    private static var lastValidMainAppFRURL: URL?
    private static var lastValidHelperFRURL: URL?
    
    @objc public static func getOriginalBundlesForMainApp(_ mainAppBundle: AutoreleasingUnsafeMutablePointer<Bundle?>, helper helperBundle: AutoreleasingUnsafeMutablePointer<Bundle?>) {
        let thisBundle = Bundle.main
        
        if runningMainApp() {
            let helperPath = thisBundle.bundleURL.appendingPathComponent(kMFRelativeHelperAppPath).path
            mainAppBundle.pointee = thisBundle
            helperBundle.pointee = Bundle(path: helperPath)
        } else if runningHelper() {
            let mainAppPath = thisBundle.bundleURL.appendingPathComponent(kMFRelativeMainAppPathFromHelperBundle).path
            mainAppBundle.pointee = Bundle(path: mainAppPath)
            helperBundle.pointee = thisBundle
        } else {
            let exception = NSException(name: NSExceptionName("UnknownCallerException"), reason: "No handling code for caller at: \(thisBundle.bundlePath)", userInfo: nil)
            exception.raise()
        }
    }
    
    @objc public static func getBundlesForMainApp(_ mainAppBundle: AutoreleasingUnsafeMutablePointer<Bundle?>, helper helperBundle: AutoreleasingUnsafeMutablePointer<Bundle?>) {
        var main: Bundle?
        var helper: Bundle?
        getOriginalBundlesForMainApp(&main, helper: &helper)
        
        if main?.executableURL == nil {
            main = nil
        }
        if helper?.executableURL == nil {
            helper = nil
        }
        
        var mainAppFRURL: URL? = nil
        if let mainURL = main?.bundleURL as NSURL? {
            mainAppFRURL = mainURL.fileReferenceURL()
        }
        if mainAppFRURL == nil {
            if let last = lastValidMainAppFRURL {
                main = Bundle(url: last)
            }
            NSLog("((Found that mainApp bundle is invalid while retrieving app bundles. Resorting to last valid fileReferenceURLs to obtain bundle. This might mean the app moved or the helper is not embedded in a mainApp.))")
        } else {
            lastValidMainAppFRURL = mainAppFRURL
        }
        
        var helperFRURL: URL? = nil
        if let helperURL = helper?.bundleURL as NSURL? {
            helperFRURL = helperURL.fileReferenceURL()
        }
        if helperFRURL == nil {
            if let last = lastValidHelperFRURL {
                helper = Bundle(url: last)
            }
            NSLog("((Found that helper bundle is invalid while retrieving app bundles. Resorting to last valid fileReferenceURLs to obtain bundle. This might mean the app moved.))")
        } else {
            lastValidHelperFRURL = helperFRURL
        }
        
        mainAppBundle.pointee = main
        helperBundle.pointee = helper
    }
}
