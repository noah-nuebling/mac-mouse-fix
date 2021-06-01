//
//  RHWeakSelectorForwarder.m
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

#import "RHWeakSelectorForwarder.h"

@implementation RHWeakSelectorForwarder

@synthesize target=_target;

-(id)initWithTarget:(id)target{
    self = [super init];
    if (self){
        if (!target) [NSException raise:NSInternalInconsistencyException format:@"Error: Unable to create an RHWeakSelectorForwarder instance with a nil target."];
        _target = target;
    }
    return self;
}

-(void)invalidate{
    _target = nil;
    _invalidated = YES;
}

-(BOOL)isValid{
    return !_invalidated;
}

//the default method forwarding technique that is used when all is well. (faster than invocations). Once invalidated we fall through to the methodSignatureForSelector: && forwardInvocation: methods below.
-(id)forwardingTargetForSelector:(SEL)aSelector{
    if (_invalidated) return nil;
    return _target; //if target is nil, we fall through to methodSignatureForSelector which then falls through to forwardInvocation:, which logs an appropriate error.
}


#pragma mark - Forwarding mechanics.

-(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector{
    id target = _target;
    
    if (_invalidated || !target){
        //make one up, (this is to force a call to forwardInvocation) its never actually used by forwardInvocation, however this allows us to ignore/raise for the erroneous call.
        return [NSMethodSignature signatureWithObjCTypes:[[NSString stringWithFormat:@"%s%s%s", @encode(void), @encode(id), @encode(SEL)] UTF8String]];
    }
    
    //query the target, if it succeeds, return it, default forwarding flow
    NSMethodSignature *targetSignature = [target methodSignatureForSelector:aSelector];
    if (targetSignature) return targetSignature;
    
    //default behaviour
    return [super methodSignatureForSelector:aSelector];
    
}

-(void)forwardInvocation:(NSInvocation *)anInvocation{
    SEL selector = [anInvocation selector];
    id target = _target;
    
    //if invalidated, complain.
    if (_invalidated){
        NSLog(@"Error: %@, which has been invalidated was asked to forward a method '%s'. Ignoring. Did you forget to invalidate your NSTimer?", self, sel_getName(selector));
        return;
    }
    
    //if no target, complain (this could happen under ARC, due to the __weak _target variable declaration)
    if (!target){
        NSLog(@"Error: %@ was asked to forward a method '%s' to a nil target.", self, sel_getName(selector));
        return;
    }
    
    
    //otherwise let _target deal with it in an appropriate manor, ie raise an exception or handle it.
    [anInvocation invokeWithTarget:target];

}

@end

