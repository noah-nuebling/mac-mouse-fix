//
//  ObserveSelf.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 01.08.24.
//

#import <Foundation/Foundation.h>

@interface NSObject (MFKVOMutationSupport)
- (void)notifyOnMutation:(BOOL)doNotify; /// Should be thread safe, not sure.
@end
