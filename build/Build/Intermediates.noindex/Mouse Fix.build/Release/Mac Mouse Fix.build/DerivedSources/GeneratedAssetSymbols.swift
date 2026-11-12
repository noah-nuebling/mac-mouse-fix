import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
extension ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
extension ImageResource {

    /// The "AppIconRoundFromHelper-deleteThis" asset catalog image resource.
    static let appIconRoundFromHelperDeleteThis = ImageResource(name: "AppIconRoundFromHelper-deleteThis", bundle: resourceBundle)

    /// The "ApplePay" asset catalog image resource.
    static let applePay = ImageResource(name: "ApplePay", bundle: resourceBundle)

    /// The "CoolMenuBarIcon" asset catalog image resource.
    static let coolMenuBarIcon = ImageResource(name: "CoolMenuBarIcon", bundle: resourceBundle)

    /// The "KeyIcon" asset catalog image resource.
    static let keyIcon = ImageResource(name: "KeyIcon", bundle: resourceBundle)

    /// The "LittleMilkshakeOutlines" asset catalog image resource.
    static let littleMilkshakeOutlines = ImageResource(name: "LittleMilkshakeOutlines", bundle: resourceBundle)

    /// The "MilkshakeButton" asset catalog image resource.
    static let milkshakeButton = ImageResource(name: "MilkshakeButton", bundle: resourceBundle)

    /// The "PayPal" asset catalog image resource.
    static let payPal = ImageResource(name: "PayPal", bundle: resourceBundle)

    /// The "UniversalAccess" asset catalog image resource.
    static let universalAccess = ImageResource(name: "UniversalAccess", bundle: resourceBundle)

    /// The "appstore" asset catalog image resource.
    static let appstore = ImageResource(name: "appstore", bundle: resourceBundle)

    /// The "arrow.triangle.branch" asset catalog image resource.
    static let arrowTriangleBranch = ImageResource(name: "arrow.triangle.branch", bundle: resourceBundle)

    /// The "arrow.up.and.down" asset catalog image resource.
    static let arrowUpAndDown = ImageResource(name: "arrow.up.and.down", bundle: resourceBundle)

    /// The "arrow.uturn.backward.circle.fill" asset catalog image resource.
    static let arrowUturnBackwardCircleFill = ImageResource(name: "arrow.uturn.backward.circle.fill", bundle: resourceBundle)

    /// The "backward" asset catalog image resource.
    static let backward = ImageResource(name: "backward", bundle: resourceBundle)

    /// The "bag" asset catalog image resource.
    static let bag = ImageResource(name: "bag", bundle: resourceBundle)

    /// The "calendar" asset catalog image resource.
    static let calendar = ImageResource(name: "calendar", bundle: resourceBundle)

    /// The "capslock" asset catalog image resource.
    static let capslock = ImageResource(name: "capslock", bundle: resourceBundle)

    /// The "cursorarrow" asset catalog image resource.
    static let cursorarrow = ImageResource(name: "cursorarrow", bundle: resourceBundle)

    /// The "exclamationmark.shield" asset catalog image resource.
    static let exclamationmarkShield = ImageResource(name: "exclamationmark.shield", bundle: resourceBundle)

    /// The "forward" asset catalog image resource.
    static let forward = ImageResource(name: "forward", bundle: resourceBundle)

    /// The "gearshape" asset catalog image resource.
    static let gearshape = ImageResource(name: "gearshape", bundle: resourceBundle)

    /// The "globe" asset catalog image resource.
    static let globe = ImageResource(name: "globe", bundle: resourceBundle)

    /// The "hands.sparkles" asset catalog image resource.
    static let handsSparkles = ImageResource(name: "hands.sparkles", bundle: resourceBundle)

    /// The "heart.text.square" asset catalog image resource.
    static let heartTextSquare = ImageResource(name: "heart.text.square", bundle: resourceBundle)

    /// The "hourglass.tophalf.filled" asset catalog image resource.
    static let hourglassTophalfFilled = ImageResource(name: "hourglass.tophalf.filled", bundle: resourceBundle)

    /// The "info.circle" asset catalog image resource.
    static let infoCircle = ImageResource(name: "info.circle", bundle: resourceBundle)

    /// The "light.max" asset catalog image resource.
    static let lightMax = ImageResource(name: "light.max", bundle: resourceBundle)

    /// The "light.min" asset catalog image resource.
    static let lightMin = ImageResource(name: "light.min", bundle: resourceBundle)

    /// The "lock" asset catalog image resource.
    static let lock = ImageResource(name: "lock", bundle: resourceBundle)

    /// The "lock.open" asset catalog image resource.
    static let lockOpen = ImageResource(name: "lock.open", bundle: resourceBundle)

    /// The "magnifyingglass" asset catalog image resource.
    static let magnifyingglass = ImageResource(name: "magnifyingglass", bundle: resourceBundle)

    /// The "mic" asset catalog image resource.
    static let mic = ImageResource(name: "mic", bundle: resourceBundle)

    /// The "minus" asset catalog image resource.
    static let minus = ImageResource(name: "minus", bundle: resourceBundle)

    /// The "minus.square" asset catalog image resource.
    static let minusSquare = ImageResource(name: "minus.square", bundle: resourceBundle)

    /// The "moon" asset catalog image resource.
    static let moon = ImageResource(name: "moon", bundle: resourceBundle)

    /// The "pencil" asset catalog image resource.
    static let pencil = ImageResource(name: "pencil", bundle: resourceBundle)

    /// The "playpause" asset catalog image resource.
    static let playpause = ImageResource(name: "playpause", bundle: resourceBundle)

    /// The "plus" asset catalog image resource.
    static let plus = ImageResource(name: "plus", bundle: resourceBundle)

    /// The "plus.square" asset catalog image resource.
    static let plusSquare = ImageResource(name: "plus.square", bundle: resourceBundle)

    /// The "power" asset catalog image resource.
    static let power = ImageResource(name: "power", bundle: resourceBundle)

    /// The "questionmark" asset catalog image resource.
    static let questionmark = ImageResource(name: "questionmark", bundle: resourceBundle)

    /// The "questionmark.square" asset catalog image resource.
    static let questionmarkSquare = ImageResource(name: "questionmark.square", bundle: resourceBundle)

    /// The "rectangle" asset catalog image resource.
    static let rectangle = ImageResource(name: "rectangle", bundle: resourceBundle)

    /// The "rectangle.3.group" asset catalog image resource.
    static let rectangle3Group = ImageResource(name: "rectangle.3.group", bundle: resourceBundle)

    /// The "rectangle.3.group.bubble.left" asset catalog image resource.
    static let rectangle3GroupBubbleLeft = ImageResource(name: "rectangle.3.group.bubble.left", bundle: resourceBundle)

    /// The "safari" asset catalog image resource.
    static let safari = ImageResource(name: "safari", bundle: resourceBundle)

    /// The "speaker" asset catalog image resource.
    static let speaker = ImageResource(name: "speaker", bundle: resourceBundle)

    /// The "speaker.wave.1" asset catalog image resource.
    static let speakerWave1 = ImageResource(name: "speaker.wave.1", bundle: resourceBundle)

    /// The "speaker.wave.3" asset catalog image resource.
    static let speakerWave3 = ImageResource(name: "speaker.wave.3", bundle: resourceBundle)

    /// The "square.grid.3x2" asset catalog image resource.
    static let squareGrid3X2 = ImageResource(name: "square.grid.3x2", bundle: resourceBundle)

    /// The "sun.max" asset catalog image resource.
    static let sunMax = ImageResource(name: "sun.max", bundle: resourceBundle)

    /// The "sun.min" asset catalog image resource.
    static let sunMin = ImageResource(name: "sun.min", bundle: resourceBundle)

    /// The "xmark.circle.fill" asset catalog image resource.
    static let xmarkCircleFill = ImageResource(name: "xmark.circle.fill", bundle: resourceBundle)

}

// MARK: - Backwards Deployment Support -

/// A color resource.
struct ColorResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog color resource name.
    fileprivate let name: Swift.String

    /// An asset catalog color resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize a `ColorResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

/// An image resource.
struct ImageResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog image resource name.
    fileprivate let name: Swift.String

    /// An asset catalog image resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize an `ImageResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// Initialize a `NSColor` with a color resource.
    convenience init(resource: ColorResource) {
        self.init(named: NSColor.Name(resource.name), bundle: resource.bundle)!
    }

}

protocol _ACResourceInitProtocol {}
extension AppKit.NSImage: _ACResourceInitProtocol {}

@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension _ACResourceInitProtocol {

    /// Initialize a `NSImage` with an image resource.
    init(resource: ImageResource) {
        self = resource.bundle.image(forResource: NSImage.Name(resource.name))! as! Self
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// Initialize a `UIColor` with a color resource.
    convenience init(resource: ColorResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}

@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// Initialize a `UIImage` with an image resource.
    convenience init(resource: ImageResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    /// Initialize a `Color` with a color resource.
    init(_ resource: ColorResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Image {

    /// Initialize an `Image` with an image resource.
    init(_ resource: ImageResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}
#endif