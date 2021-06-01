//
//  RHWeakSelectorForwarder.h
//
//  Created by Richard Heard on 9/09/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//  derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// A class that maintains a weak pointer to an object, and forwards any methods
// called on it to its target.
//
// This is useful when you have an NSTimer inside a long lived controller,
// that must run until dealloc'd. (to avoid retain cycles)
//
// We have the timer retain our forwarding object which holds a weak pointer
// to ourselves, hence breaking any retain cycle.


#import <Foundation/Foundation.h>
#import "RHARCSupport.h"

@interface RHWeakSelectorForwarder : NSObject {

#if ARC_IS_ENABLED
    __weak id _target;
#else
    id _target;
#endif
    
    BOOL _invalidated;
}

-(id)initWithTarget:(id)target; //designated initialiser

#if ARC_IS_ENABLED
    @property (nonatomic, weak) id target;
#else
    @property (nonatomic, assign) id target;
#endif

-(void)invalidate; //nils the target; must be called before target goes away, i.e. from inside targets dealloc method
-(BOOL)isValid;

@end

