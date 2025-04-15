//
//  DeallocTracker.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 02.08.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeallocTracker : NSObject
@property (strong, nonatomic) void (^deallocCallback)(__unsafe_unretained NSObject *deallocatingObject);
@property (unsafe_unretained, nonatomic) NSObject *trackedObject; /// Use `unsafe_unretained`. weak ptr would be nil in the deallocCallback, and strong would cause memory leak. If anyone else than the trackedObject retains the dealloc tracker, it won't work anymore.
@end


NS_ASSUME_NONNULL_END
