//
// --------------------------------------------------------------------------
// TabControllerUtility.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

func applyHardcodedTabWidth(_ tabName: String, _ tabController: NSViewController, widthControllingTextFields: [NSTextField?]) -> Void {

    /// TODO:
    ///     - [ ] Set widths for Turkish
    ///         There are already some Turkish strings but too few to make decisions [Sep 2025]

    /// Determine width for this tab
    ///     Discussion: [Sep 2025]
    ///         Before: We used to control the tab width through the linebreaks in the hints.
    ///         Problem: But that means localizers need to 'design' the tab width – but without being able to see what their choice looks like in-app (Unless they're building from source)
    ///         Solution: So now we're hardcoding the tab-width in code instead! [Sep 2025]
    ///             Con: If localizers manually choose linebreaks, they can set them where it feels smooth and helps parse the text. This is no longer possible when we automate linebreaks.
    ///                 Pro: But since the hints are very short sentences, it shouldn't matter too much.
    ///                 Pro: Also, we can still try to set the programmatic width such that the linebreaks don't happen in places that are too awkward.
    ///         Alternative approaches to hardcoding widths:
    ///             - I tried finding some specific margins we could constraint with autolayout to make the layout look good in any language, but I couldn't. I think what makes the layout look good is a complex interplay between whitespaces and distribution of visual weight and proportions and stuff – just hardcoding the width of the entire layout seems the most pragmatic solution. [Sep 2025]
    ///                 - Update: we ended up making everything 350 wide ... Not sure what's going on but it looks good [Sep 2025]
    
    /// How to choose a hardcoded tab-width: [Sep 2025]
    ///     - Pick what looks good in English
    ///     - If there are awkward line-wrappings or truncations, make wider
    ///         - Don't forget sections that are hidden by default (macOSHint)
    ///         - Text under 'Scrolling > Keyboard Modifiers:' can't wrap, so make sure it doesn't truncate. [Sep 2025]
    ///     - If there is awkward whitespace, make narrower (so far, we only did that for CJK languages, which makes sense since they have the highest informationDensity)
    ///
    ///     History:
    ///         - [Dec 2025] Change horizontal margins around the labels under `Scrolling > Keyboard Modifiers` from 10 to 5.
    ///             - [ ] TODO -> This should perhaps make us reconsider some widths like `"pt": 370`
    
    /// Set the window width for this tab
    do {
        var map: [String: Double]
        switch tabName {
            case "general":
                map = [ /// See `[LocalizationUtility informationDensityOfCurrentLanguage]` for all the language codes [Sep 2025]
                    
                    "en": 420,
                    "zh": 420,   /// 320 -> 420. Prevent toolbar items from overflowing (About/关于 hidden under >>) since we now have 6 tabs
                    "fr": 420,   /// 350 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "de": 420,   /// 350 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "ko": 420,   /// 320 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "pt": 420,   /// 350 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "vi": 420,   /// 350 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "cs": 420,   /// 320 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "tr": 420,   /// 350 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "ru": 420,
                    "es": 420,   /// 370 -> 420. Prevent toolbar overflow due to 6 tabs.
                ]
            case "scrolling":
                map = [
                    "en": 420,  /// 340 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "zh": 420,  /// 330 -> 420. Prevent toolbar items from overflowing since we now have 6 tabs.
                    "fr": 420,  /// 360 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "de": 420,  /// 340 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "ko": 420,  /// 330 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "pt": 420,  /// 370 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "vi": 420,  /// 340 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "cs": 420,  /// 340 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "tr": 420,  /// 380 -> 420.
                    "ru": 420,  /// 350 -> 420. Prevent toolbar overflow due to 6 tabs.
                    "es": 420,  /// 390 -> 420.
                ]
            default:
                fatalError("Calling this from unexpected tab: \(tabController)")
        }
        
        var windowWidth = map[LocalizationUtility.currentLanguageCode() ?? ""]
        if (windowWidth == nil) {
            assert(false)
            windowWidth = map["en"]! /// Fallback in case I forget to update the map for a new language [Sep 2025]
        }
        
        if (windowWidth! >= 0) {
            
            /// Set window width
            ///     Before, I used `lessThanOrEqualToConstant:` instead of `equalToConstant:` to make things more robust in case the layout naturally wants to be narrower.
            ///         But allowing textWrapping without specifying tabWidth leads to these weird ambiguities in the layout system I think. Wrote more about this elsewhere where we mentioned `applyHardcodedTabWidth` [Sep 2025]
            tabController.view.widthAnchor.constraint(equalToConstant: windowWidth!).isActive = true;
            
            /// Enable text wrapping
            for t in widthControllingTextFields {
                t?.setContentCompressionResistancePriority(.init(999), for: .horizontal)
            }
            /// Remove manual linebreaks
            for t in widthControllingTextFields {
                /// - [ ] TODO: Insert an assert(false) here if we still find manual linebreaks. (?)
                t?.attributedStringValue = t!.attributedStringValue.replacing("\n", with: " ".attributed())
            }
        }
        else {
            
            /// Set the tab width to -1 to let the tab take it's natural size
            
            assert(false) /// Disabling this because the macOSHint code on the ScrollTab cannot support this anymore. [Sep 2025]
        
            /// Disable text wrapping
            ///     Leaving the compressionResistance to 999, the textFields start wrapping kinda randomly. Setting width to 999999 at priority 999 also seem to help. Not sure what's going on. [Sep 2025]
            for t in widthControllingTextFields {
                assert(t?.contentCompressionResistancePriority(for: .horizontal) == .init(1000)) /// This is what we're already doing in IB, this is just for documentation [Sep 2025]
                t?.setContentCompressionResistancePriority(.init(1000), for: .horizontal)
            }
        }
        
        print("TBS set windowWidth \(windowWidth!) for tab '\(tabName)' (\(tabController.view))")
        
    }
}
