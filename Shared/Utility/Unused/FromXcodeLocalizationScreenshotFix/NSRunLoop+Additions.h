//
//  NSRunLoop+Additions.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 18.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSRunLoop (Additions)

- (NSDictionary *)observeLoopActivities:(CFRunLoopActivity)activities withCallback:(void (^)(CFRunLoopObserverRef observer, CFRunLoopActivity activity))callback;
- (void)stopObservingLoopActivitiesWithResultDict:(NSDictionary *)resultDict;

@end

NS_ASSUME_NONNULL_END
