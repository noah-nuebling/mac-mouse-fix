//
// --------------------------------------------------------------------------
// NSArray+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface NSArray (Additions)

    - (NSMutableAttributedString *) attributedComponentsJoinedByString: (NSAttributedString *)joiner;

    #if 0
        - (NSArray *)map:(id (^)(id obj))block;
        - (NSArray *)filter:(BOOL (^)(id obj))block;
        - (id)reduce:(id)initial
               block:(id (^)(id obj1, id obj2))block;
        - (NSArray *)flatMap:(id (^)(id obj))block;
        - (NSArray *)flattenedArray;
    #endif
    
    #if 0
        + (NSMutableArray *)doDeepMutateArray:(NSArray *)array;
    #endif
@end
