//
//  RHARCSupport.h
//
//  Created by Richard Heard on 3/07/12.
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
// supporting macros for code to allow building with and without arc


#ifndef __has_feature
// not LLVM Compiler
#define __has_feature(x) 0
#endif

#ifndef CF_CONSUMED
#if __has_feature(attribute_cf_consumed)
#define CF_CONSUMED __attribute__((cf_consumed))
#else
#define CF_CONSUMED
#endif
#endif


// ----- ARC Enabled -----
#if __has_feature(objc_arc) && !defined(ARC_IS_ENABLED)

#define ARC_IS_ENABLED 1

//define retain count macro wrappers
#define arc_retain(x)       (x)
#define arc_release(x)
#define arc_release_nil(x)  (x = nil)
#define arc_autorelease(x)  (x)
#define arc_super_dealloc()

//add CF bridging methods
#define ARCBridgingRetain(x)    CFBridgingRetain(x)
#define ARCBridgingRelease(x)   CFBridgingRelease(x)

#endif


// ----- ARC Disabled -----
#if !__has_feature(objc_arc) && !defined(ARC_IS_ENABLED)

#define ARC_IS_ENABLED 0

//define retain count macro wrappers
#define arc_retain(x)       ([x retain])
#define arc_release(x)      ([x release])
#define arc_release_nil(x)   [x release]; x = nil;
#define arc_autorelease(x)  ([x autorelease])
#define arc_super_dealloc() ([super dealloc])

//add arc keywords if not already defined
#ifndef __bridge
#define __bridge
#endif
#ifndef __bridge_retained
#define __bridge_retained
#endif
#ifndef __bridge_transfer
#define __bridge_transfer
#endif

#ifndef __autoreleasing
#define __autoreleasing
#endif
#ifndef __strong
#define __strong
#endif
#ifndef __weak
#define __weak
#endif
#ifndef __unsafe_unretained
#define __unsafe_unretained
#endif

//add CF bridging methods (we inline these ourselves because they are not included in older sdks)
NS_INLINE CF_RETURNS_RETAINED CFTypeRef ARCBridgingRetain(id X) {
    return X ? CFRetain((CFTypeRef)X) : NULL;
}

NS_INLINE id ARCBridgingRelease(CFTypeRef CF_CONSUMED X) {
    return [(id)CFMakeCollectable(X) autorelease];
}

#endif


//if clarity helper
#define ARC_IS_NOT_ENABLED (!(ARC_IS_ENABLED))

