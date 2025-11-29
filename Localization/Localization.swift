//
// --------------------------------------------------------------------------
// Localization.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

public func MFLocalizedString(_ key: Swift.String, tableName: Swift.String? = nil, bundle: Foundation.Bundle = Bundle.main, value: Swift.String = "", comment: Swift.String) -> Swift.String {
    /// Function signature matches `Foundation.framework/Versions/C/Modules/Foundation.swiftmodule/arm64e-apple-macos.swiftinterface` from the macOS sdk
    return _MFLocalizedString(key)
}
