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

    ///     TODO: [Sep 28 2025]
    ///         Update / remove all the stuff pertaining to 'semanting linebreaks'
    ///             - Localizer hints & code-comments:
    ///                 - [ ] Go over localizer hints for all the hints on the General and Scrolling Tabs
    ///                     - Also adjust the related code comments
    ///                     - Some of them mention that you *don't* have to set linebreaks to control the width – remove that too.
    ///                 - [ ] Go over the other localizer hint mentioning 'too wide'
    ///                 - [ ] Check if there are any other localizable strings with 'width-controlling linebreaks'?
    ///         - [x] Remove the linebreak in Korean
    ///             - AHn-zX-g4d.title (This is not width-determining, so shouldn't have any linebreaks to begin with)
    ///             - AqN-zN-yDS.title (widthDetermining)
    ///                 ... [ ] Or just give Korean an explicit width
    ///         - Translated strings:
    ///             - [ ] Remove 'z' after `Aumentar ou diminuir`
    ///         - [ ] Test if the macOSHint being swapped in still works (Scrolling Tab)


    /// Determine width for this tab
    ///     Discussion: [Sep 2025]
    ///         Before: We used to control the tab width through the linebreaks in the hints.
    ///         Problem: But that means localizers need to 'design' the tab width – but without being able to see what their choice looks like in-app (Unless they're building from source)
    ///         Solution: So now we're hardcoding the tab-width in code instead! [Sep 2025]
    ///             Con: If localizers manually choose linebreaks, they can set them where it feels smooth and helps parse the text. This is no longer possible when we automate linebreaks.
    ///                 Pro: But since the hints are very short sentences, it shouldn't matter too much.
    ///                 Pro: Also, we can still try to set the programmatic width such that the linebreaks don't happen in places that are too awkward. (Also, not sure the 'awkward' linebreaks are even noticable in these short lines))
    ///         Alternative approaches to hardcoding widths:
    ///             - I tried finding some specific margins we could constraint with autolayout to make the layout look good in any language, but I couldn't. I think what makes the layout look good is a complex interplay between whitespaces and distribution of visual weight and proportions and stuff – just hardcoding the width of the entire layout seems the most pragmatic solution. [Sep 2025]
    ///                 - ... Then we ended up making everything 350 wide ... Not sure what's going on but it looks good [Sep 2025]
    ///
    /// Principles of how we choose a hardcoded tab-width: [Sep 2025]
    ///     - Pick what looks good in English
    ///     - If there are awkward line-wrappings, make wider
    ///     - If there is awkward whitespace, make shorter (so far, only CJK languages with high informationDensity)
    
    /// Set the window width for this tab
    do {
        var map: [String: Double]
        switch tabName {
            case "general":
                map = [ /// See `[LocalizationUtility informationDensityOfCurrentLanguage]` for all the language codes [Sep 2025]
                    
                    "en": 350,
                    "zh": 320,   /// 350 -> 320 looks nicer than 350 (even though it wraps the enabledHint) [Sep 2025]
                    "fr": 370,   /// 350 -> 370 is narrowest that doesn't wrap the pretty-short first enabledHint [Sep 2025]
                    "de": 350,   /// 350 looks great. [Sep 2025]
                    "ko": 320,   /// 350 -> 320 minimize gap after short enabledHint "Mac Mouse Fix는 창을 닫아도 동작합니다." [Sep 2025]
                    "pt": 350,   /// 350 looks great. 370 is closest to the 'vision' of the original translator I think – the 2nd and 3rd hint have the last two words on the 2nd line. But 350 looks better visually I think. [Sep 2025]
                    "vi": 350,   /// 350 looks great and is almost exactly what the original translator did [Sep 2025]
                ]
            case "scrolling":
                map = [
                    "en": 340,  /// 340 looks great and is very close to what what our non-semantic linebreaks produced. Being different from general tab makes animation a bit more interesting. [Sep 2025]
                    "zh": -1,   /// Everything's 1 line in Chinese [Sep 2025]
                    "fr": 360,  /// 340 -> 360 is the narrowest, that doesn't wrap the precisionHint onto 3 lines. [Sep 2025]
                    "de": 340,  /// 340 looks great [Sep 2025]
                    "ko": 330,  /// 340 -> 330 looks better. Not sure why. [Sep 2025]
                    "pt": 350,  /// 340 -> 350 is narrowest that doesn't wrap the precisionHint to 3 lines [Sep 2025]
                    "vi": 340,  /// 340 looks great. [Sep 2025]
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
