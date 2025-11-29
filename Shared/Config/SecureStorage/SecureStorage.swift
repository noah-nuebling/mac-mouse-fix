//
// --------------------------------------------------------------------------
// SecureStorage.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Discussion:
/// - This is a wrapper around the keychain so we can store and retrieve values with simple keypath-based syntax.
/// - All settings are stored in a dictionary inside a single keychain item labeled 'com.nuebling.mac-mouse-fix.secure-storage'.
/// - vs storing in config.plist, this has the advantage that the keychain is synced to all the users devices.
/// - It also isn't automatically deleted on uninstall by apps like AppCleaner by FreeMacSoft. This makes it a little more annoying to reset the trial period.
/// - Special entitlements on the mainApp and Helper let both access the same keychain item.
/// - See the great Apple documentation for more info:
///     - https://developer.apple.com/documentation/security/keychain_services/keychain_items?language=objc

/// In the same folder as this file, there's `default_secureStorage.plist`. At the time of writing, this is unused. It's never actually installed like the `default_config.plist` is. It serves a note on the structure of the secureStorage.

/// - When to use this?
///     - ... when losing the information could have negative consequences for the user.
///         - E.g. license key.
///         - Note: Currently this isn't that important since our maxNumberOfActivations is very high and most people will be able to retrieve the key from their email if they lose it .
///     - ... when manipulating the information allows you to use the app for free, AND there's no external source of truth like a server (So the value isn't just a cache that gets updated when there's internet)
///         - E.g. daysOfUse counter during trial period
///     - ... when the data shouldn't be deleted after uninstalling MMF
///         - E.g. license key, daysOfUse counter during trial
/// - When __not__ to use this?
///     - In all other cases, just use config to store data. I assume it's faster and it's more accessible to users for debugging or deleting after uninstall.
/// - Do we user __UserDefaults__?
///     - No. config fills the same roll.

/// TODO: Implement cleanup function. See Notes in NSDictionary+Additions.m for details.

import Foundation

@objc class SecureStorage: NSObject {
    
    /// Surface lvl 2
    
    @objc static func delete(_ keyPath: String){
        set(keyPath, value: nil)
    }
    
    @objc static func getAll() -> NSDictionary? {
        do {
            let dict = try readDict()
            return dict
        } catch {
            return nil
        }
    }
    
    /// Surface
    
    @objc static func get(_ keyPath: String) -> Any? {
        
        do {
            let dict = try readDict()
            return dict.object(forCoolKeyPath: keyPath)
            
        } catch {
            return nil
        }
    }
    
    @objc static func set(_ keyPath: String, value: Any?) {
        
        do {
            let dict = try readDict().mutableCopy() as! NSMutableDictionary
            dict.setObject((value as! NSObject?), forCoolKeyPath: keyPath)
            
            try replaceDict(dict)
        
        } catch KeychainError.itemNotFound {
            
            do {
                try createItem(dict: [:])
                set(keyPath, value: value)
                
            } catch {
                assert(false)
            }
            
        } catch {
            assert(false)
        }
    }
    
    /// Core lvl 2
    
    private static func readDict() throws -> NSDictionary {
        
        let data = try readItem()
        
        do {
            
            /// Unarchive data into dict
            ///     I think this is secure since other apps can't write to our keychain item.
            var dict = try SharedUtilitySwift.insecureUnarchive(data: data as Data)
            
            /// Catch wrong type
            ///     For some reason I saw the item be a string at some point, causing a crash, so we guard against that here.
            if let dict = dict as? NSDictionary {

            } else {
                DDLogWarn("The Secure storage item can't be cast to an NSDictionary. It's value is \(dict). Just pretending like it's an empty dict instead.")
                dict = NSDictionary()
            }
                
            /// Return
            return dict as! NSDictionary
            
        } catch {
            assert(false)
            throw KeychainError.invalidItemData
        }
    }
    
    private static func replaceDict(_ dict: NSDictionary) throws {
        
        let data = try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false)
        try updateItem(data: data as CFData)
    }
    
    private static func createItem(dict: NSDictionary) throws {
        
        let data = try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false)
        try createItem(data: data as CFData)
    }
    
    /// Core lvl 1
    
    private static func createItem(data: CFData) throws {
        
        /// Note: The docs say to use SecItemAdd() from a background thread since it blocks the calling thread, but it seems fine so far.
        
        var query = baseQuery()
        query[kSecValueData as String] = data
        
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }
    
    private static func updateItem(data: CFData) throws {
        
        let query = baseQuery()
        
        let updates = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        
        guard status != errSecItemNotFound else { throw KeychainError.itemNotFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }
    
    private static func readItem() throws -> CFData {
        
        var query = baseQuery()
        query[kSecReturnData as String] = kCFBooleanTrue!
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else { throw KeychainError.itemNotFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        
        guard
            let item = item,
            CFGetTypeID(item) == CFDataGetTypeID()
        else {
            throw KeychainError.invalidItemData
        }
        
        return item as! CFData
    }
    
    /// Core lvl 0
    
    private static let label = "com.nuebling.mac-mouse-fix.secure-storage" /// "MFSecureStorage"
    
    private static func baseQuery() -> [String: Any] {
        
        let query: [String: Any] = [
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrLabel as String: label,
        ]
        
        return query
    }
    
    /// Define errors
    
    private enum KeychainError: Error {
        case unhandledError(status: OSStatus)
        case itemNotFound
        case invalidItemData
    }
}
