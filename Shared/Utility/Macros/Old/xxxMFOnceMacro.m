//
//  MFOnce.m
//  objc-tests-nov-2024
//
//  Created by Noah Nübling on 05.02.25.
//


#define MF_TEST 0

#if MF_TEST

    #import "MFOnce.h"
    #import "objc/objc-sync.h"

    @interface MFOnce : NSObject

    @implementation MFOnce

    + (void) load {

        /// Test / usage example
        
        NSArray *(^getCoolNums)(void) = ^{
            
            /// Make mfonce EVEN MORE CONCISE
            #define mfstatic(varname) varname; mfonce varname
            
            /// Concise mfonce
            static NSArray *mfstatic(coolNums) = @[@1, @2, @3].mutableCopy; /// mutableCopy should create a fresh object every time it's called (but it'll only be called once håhaahahahaha)
            
            /// Verbose `dispatch_once`
            static NSArray *coolNums2;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                coolNums2 = @[@1, @2, @3].mutableCopy;
            });
            
            /// Return
            return coolNums;
            
            /// I really dislike Swift in large part for how they overvalue conciseness, and are too complex. But then I do this.. At least I know I shouldn't be a language designer.
        };
        
        NSLog(@"MFOnce test: coolNums: %@, %p", getCoolNums(), getCoolNums());
        NSLog(@"MFOnce test: coolNums: %@, %p", getCoolNums(), getCoolNums());
        NSLog(@"MFOnce test: coolNums: %@, %p", getCoolNums(), getCoolNums());
    }

    @end

#endif
