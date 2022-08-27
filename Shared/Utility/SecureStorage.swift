//
// --------------------------------------------------------------------------
// SecureStorage.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This is a wrapper around the keychain so we can store and retrieve values with simple keypath-based syntax.
/// All settings are stored in a dictionary inside a single keychain item.
/// vs storing in config.plist, this has the advantage that the keychain is synced to all the users devices.
/// It also isn't automatically deleted on uninstall by apps like AppCleaner by FreeMacSoft. This makes it a little more annoying to reset the trial period.
/// Special entitlements on the mainApp and Helper let both access the same keychain item.
/// See the great Apple documentation for more info: https://developer.apple.com/documentation/security/keychain_services/keychain_items?language=objc

import Foundation

@objc class SecureStorage: NSObject {
    
    /// Surface
    
    @objc func get(_ keyPath: String) -> Any? {
        
        do {
            let dict = try readDict()
            return dict.value(forKeyPath: keyPath)
            
        } catch {
            return nil
        }
    }
    
    @objc func set(_ keyPath: String, _ value: Any) {
        
        do {
            let dict = try readDict()
            dict.setValue(value, forKeyPath: keyPath)
            
            try replaceDict(dict)
        
        } catch KeychainError.itemNotFound {
            
            do {
                try createItem(dict: [:])
                set(keyPath, value)
                
            } catch {
                assert(false)
            }
            
        } catch {
            assert(false)
        }
    }
    
    /// Core lvl 2
    
    private func readDict() throws -> NSDictionary {
        
        let data = try readItem()
        guard let dict = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: data as Data) else {
            throw KeychainError.invalidItemData
        }
        
        return dict
    }
    
    private func replaceDict(_ dict: NSDictionary) throws {
        
        let data = try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false)
        try updateItem(data: data as CFData)
    }
    
    private func createItem(dict: NSDictionary) throws {
        
        let data = try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false)
        try createItem(data: data as CFData)
    }
    
    /// Core lvl 1
    
    private let label = "MFSecureStorage"
    
    private func createItem(data: CFData) throws {
        
        var query = baseQuery()
        query[kSecValueData] = data
        
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }
    
    private func updateItem(data: CFData) throws {
        
        let query = baseQuery()
        
        let updates = [
            kSecValueData: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        
        guard status != errSecItemNotFound else { throw KeychainError.itemNotFound }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }
    
    private func readItem() throws -> CFData {
        
        var query = baseQuery()
        query[kSecReturnData] = kCFBooleanTrue!
        
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
    
    private func baseQuery() -> [CFString: Any] {
        
        let query: [CFString: Any] = [
            kSecAttrSynchronizable: kCFBooleanTrue!,
            kSecClass: kSecClassGenericPassword,
            kSecAttrLabel: label,
        ]
        
        return query
    }
    
    /// Define errors
    
    enum KeychainError: Error {
        case unhandledError(status: OSStatus)
        case itemNotFound
        case invalidItemData
    }
}
