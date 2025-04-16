//
//  EventLoggerForBradUtility.h
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 16.04.25.
//

///
/// [Apr 2025] Utilities from EventLoggerForBrad that are *not* macros.
///     Created this for cleanly moving code over to MMF repo.
///     - [ ]  TODO: Merge into SharedUtility.m or something.
///

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EventLoggerForBradUtility : NSObject
static inline NSString *_Nonnull bitflagstring(int64_t flags, NSString *const _Nullable bitToNameMap[_Nullable], int bitToNameMapCount);
@end

NS_ASSUME_NONNULL_END
