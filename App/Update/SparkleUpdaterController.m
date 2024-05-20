//
// --------------------------------------------------------------------------
// SparkleUpdateDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SparkleUpdaterController.h"
#import "AppDelegate.h"
#import "SharedUtility.h"
#import "Locator.h"
#import "HelperServices.h"

// See https://sparkle-project.org/documentation/customization/

@implementation SparkleUpdaterController

- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast forUpdater:(SUUpdater *)updater {
    
    /// Custom logic
    ///
    /// - 1. When going to a new major version, we always want to update to the initial x.0.0 release first.
    ///     - That's so the user sees the x.0.0 update notes with all the major changes. 
    ///     - This is important, if the new major version is a paid update
    /// - 2. If there's a free update, we prioritize that.
    ///     - E.g. MMF 2.2.5 -> 2.2.6 will be presented over 2.2.5 -> 3.0.0 --- because MMF 2 -> MMF 3 is a paid update.
    ///
    /// Discussion:
    /// - Discussion of custom logic: https://github.com/noah-nuebling/mac-mouse-fix/issues/962#issuecomment-2120238813
    /// - As far as I understand, the `appcast` arg is already prefiltered by Sparkle using stuff like skippedUpdates, minimumAutoupdateVersion and minimumOSVersion.
    ///   Also, as far as I understand, the default implementation simply uses [delegate versionComparator] (which defaults to a `SUStandardVersionComparator`) to get the appCast item with the highest version.
    ///     - I base these assumptions the following Sparkle 2 source code (we're using Sparkle 1 at the time of writing, but I hope nothing drastic changed): https://github.com/sparkle-project/Sparkle/blob/2247105ff37ba7b317e65af9833ecbb0f67f81de/Sparkle/SUAppcastDriver.m#L230
    /// - I think logically, we're really just implementing a custom comparator. We'd probably be able to achieve the same thing by simply returning a custom SUComparator from this delegate, but I don't think it matters.
    
    
    /// Extract updates
    NSArray <SUAppcastItem *> *updates = appcast.items;
    
    /// DEBUG: Shuffle updates
    ///     -> So that we can see if the sorting really works reliably
    void(^shuffleArray)(NSMutableArray *) = ^(NSMutableArray *array) {
        if (array.count <= 1) return;
        for (NSUInteger i = 0; i < array.count - 1; i++) {
            NSInteger remainingCount = array.count - i;
            NSInteger exchangeIndex = i + arc4random_uniform((u_int32_t )remainingCount);
            [array exchangeObjectAtIndex:i withObjectAtIndex:exchangeIndex];
        }
    };
    updates = updates.mutableCopy;
    shuffleArray((id)updates);
    
    /// Extract current version
    NSString *currentVersion = Locator.bundleVersionShort;
    int currentMajorVersion = [[currentVersion substringToIndex:1] intValue];
    NSInteger currentBuildNumber = Locator.bundleVersion;
    
    /// Create comparator
    SUStandardVersionComparator *comparator = [SUStandardVersionComparator defaultComparator];
    
    /// Find best update in appcast
    SUAppcastItem *bestUpdate = nil;
    for (SUAppcastItem *candidateUpdate in updates) {
        
        /// Init result
        /// Note: On each iteration, our goal is to determine whether the candidateUpdate is better than the current bestUpdate.
        BOOL candidateIsBetter;
        
        /// Extract versions
        NSString *bestVersion = bestUpdate.displayVersionString; /// bestVersion may be nil if bestUpdate is nil
        NSString *candidateVersion = candidateUpdate.displayVersionString;
        NSInteger bestBuildNumber = bestUpdate.versionString.integerValue;
        NSInteger candidateBuildNumber = candidateUpdate.versionString.integerValue;
        
        /// Split off major version
        /// Note:
        /// - This wouldn't work if MMF ever used a v prefix for any version release. E.g. v1.0.0. But we never did, so this should work.
        /// - I think it might be ideal to tap into the `SUStandardVersionComparator`s internal logic, since it already has sophisticated logic to parse the major, minor version, etc. But that's too hard and annoying I think.
        int bestMajorVersion = bestVersion == nil ? -1 : [[bestVersion substringToIndex:1] intValue];
        int candidateMajorVersion = [[candidateVersion substringToIndex:1] intValue];
        
        /// Compare version numbers
        BOOL candidateIsLaterThanBest = [comparator compareVersion:bestVersion toVersion:candidateVersion] == NSOrderedAscending;
        BOOL candidateIsEarlierThanBest = [comparator compareVersion:bestVersion toVersion:candidateVersion] == NSOrderedDescending;
        BOOL candidateIsSameVersionAsBest = !candidateIsLaterThanBest && !candidateIsEarlierThanBest;
        
        BOOL candidateIsLaterThanCurrent = [comparator compareVersion:currentVersion toVersion:candidateVersion] == NSOrderedAscending;
        BOOL candidateIsEarlierThanCurrent = [comparator compareVersion:currentVersion toVersion:candidateVersion] == NSOrderedDescending;
        BOOL candidateIsSameVersionAsCurrent = !candidateIsLaterThanCurrent && !candidateIsEarlierThanCurrent;
        
        /// Debug
        NSLog(@"DEBUG Comparing current best update: %@ (mv %d), with candidate update: %@ (mv %d) --- Current version %@ (mv %d)", bestVersion, bestMajorVersion, candidateVersion, candidateMajorVersion, currentVersion, currentMajorVersion);
        
        /// Determine free vs paid updates
        BOOL(^isFreeUpdate)(int, int) = ^(int currentMajorVersion, int updateMajorVersion) {
            
            BOOL updateIsFree = currentMajorVersion >= updateMajorVersion; /// If the update doesn't have a higher major version, it's definitely free, otherwise we initialize to not free.
            
            if (updateMajorVersion == -1) {       ///  Does this case matter?
                
            } else if (updateMajorVersion == 1) { /// `MMF 0.9 -> MMF 1` is a free update
                updateIsFree = YES;
            } else if (updateMajorVersion == 2) { /// `MMF 0.9 -> MMF 2` and `MMF 1 -> MMF 2` are free updates
                updateIsFree = YES;
            }
            return updateIsFree;
        };
        
        BOOL candidateIsFreeUpdate = isFreeUpdate(currentMajorVersion, candidateMajorVersion);
        BOOL bestIsFreeUpdate = isFreeUpdate(currentMajorVersion, bestMajorVersion);
        
        /// Determine whether the candidate update is better than the `best` update
        
        /// Rule 0: Skip older/equal versions
        ///     Note: I thought Sparkle would already filter older versions out, but apparently not
        
        if (candidateIsEarlierThanCurrent ||
            (candidateIsSameVersionAsCurrent && candidateBuildNumber <= currentBuildNumber)) {
            
            candidateIsBetter = NO;
            goto loopEnd;
        }
        
        /// Rule 1: We always prioritize free updates
        if (bestUpdate != nil 
            && candidateIsFreeUpdate != bestIsFreeUpdate) {
            
            candidateIsBetter = candidateIsFreeUpdate;
            goto loopEnd;
        }
        
        /// Rule 2: When jumping to a new major version - update to the initial release of that major version.
        if (candidateMajorVersion == bestMajorVersion       /// If we're deciding between two versions of the same major release
            && candidateMajorVersion > currentMajorVersion) {       /// ... And that major release is different from the current major release
            
            candidateIsBetter = !candidateIsLaterThanBest;          /// ... Then we always choose the older release
            goto loopEnd;
        }
        
        /// Validate
        assert(!candidateIsEarlierThanCurrent); /// This case should be filtered out by logic above
        
        /// Rule 3: Otherwise, update to the later version
        
        if (candidateIsLaterThanBest) {
            candidateIsBetter = YES;
            goto loopEnd;
        } else if (candidateIsEarlierThanBest) {
            candidateIsBetter = NO;
            goto loopEnd;
        }
        
        /// Validate
        assert(candidateBuildNumber > currentBuildNumber);
        
        /// Rule 4: If both versions are the same (which is the case here since Rule 3 didn't decide anything) -> compare the build number instead
        
        if (candidateBuildNumber > bestBuildNumber) { /// Not sure how important it is that here we're choosing `>` over `>=`
            candidateIsBetter = YES;
            goto loopEnd;
        } else {
            candidateIsBetter = NO;
            goto loopEnd;
        }
        
    loopEnd:
        if (candidateIsBetter) {
            bestUpdate = candidateUpdate;
        }
        
    }
    
    return bestUpdate;
}

+ (void)enablePrereleaseChannel:(BOOL)pre {
    if (pre) {
        SUUpdater.sharedUpdater.feedURL = [NSURL URLWithString:stringf(@"%@/%@", kMFUpdateFeedRepoAddressRaw, kSUFeedURLSubBeta)];
    } else {
        SUUpdater.sharedUpdater.feedURL = [NSURL URLWithString:stringf(@"%@/%@", kMFUpdateFeedRepoAddressRaw, kSUFeedURLSub)];
    }
}

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater {
    // We don't use Sparkles automatic scheduled updates anyways. Instead we simply check every time the app is started. So what the user chooses in this prompt doesn't make difference anyways. So were disabling the prompts.
    return NO;
}

- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update {
    
    NSLog(@"About to install update");
    
    [MoreSheet.instance end]; // Close more sheet so it doesn't block popup
}

- (void)updaterDidRelaunchApplication:(SUUpdater *)updater {
    
    NSLog(@"Has been launched by Sparkle Updater");
    
    /// Log the fact that updater launched the application in appState()
    ///     We use this from `AppDelegate - applicationDidFinishLaunching`.
    appState().updaterDidRelaunchApplication = YES;
    
    /// Kill helper
    /// It might be more robust and simple to find and kill any strange helpers *whenever* the app starts, but this should work, too.
    [HelperServices killAllHelpers];
    
}



@end
