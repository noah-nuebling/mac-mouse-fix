## RHAdditions

Various Objective-C categories and additions that have served me well over the years.
Hopefully then can serve you too!


## Licence

Released under the Modified BSD License. (Attribution Required)
<pre>
RHAdditions

Copyright (c) 2011-2013 Richard Heard. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
</pre>


##Content Overview
	
###RHARCSupport
Supporting macros to allow for building both with and without ARC enabled. 

###RHLoggingSupport
Provides debug and error logging macros.

###NSArray+RHFirstObjectAdditions
Adds a `firstObject` method for balance.
 
###NSBundle+RHLaunchAtLoginAdditions
Adds support for Launch At Login via `SMLoginItemSetEnabled()`.

###NSImage+RHImageRepresentationAdditions
Adds various (PNG / JPEG / GIF) representations.

###NSObject+RHClassInfoAdditions
Adds a `logClassInfo` method to dump a classes ivars, properties and methods.

###NSString+RHNumberAdditions
Adds a bunch of number methods to better reflect those available on NSNumber.

###NSString+RHRot13Additions
Adds a rot13 method for various "non security related" purposes.

###NSString+RHURLEncodingAdditions
Adds URL encoding methods.

###NSThread+RHBlockAdditions
Adds methods for running blocks on specific threads. Useful when specific tasks need to be performed on a specific thread etc.

###NSView+RHSnapshotAdditions
Provides NSView snapshotting, useful for animations and cover transitions.

###UIView+RHSnapshotAdditions
Provides UIView snapshotting, useful for animations and cover transitions.

###NSWindow+RHResizeAdditions
Adds a method to allow for resizing of a windows contentSize over a specific duration.

###UIApplication+RHStatusBarBoundsAdditions
Adds statusBar width, height and bounds methods.

###UIColor+RHInterpolationAdditions
Provides interpolation between 2 UIColors, useful for frame animations etc.

###UIDevice+RHDeviceIdentifierAdditions
Provides a mac address / sha1 based set of device identifiers.

###UIImage+RHComparingAdditions
Adds pixel level image comparison, supports various thresholds for slight variations in images (eg from colour correction etc.)
Also supports resizing one of the 2 images being compared if they are not the same size, so that a px by px comparison is possible.

###UIImage+RHPixelAdditions
Adds support for accessing the underlying raw pixel data of a UIImage, both in bulk and on a point by point basis.
Returned format is RGBA pre-multiplied as is supported by CoreGraphics.

###UIImage+RHResizingAdditions
Adds support for resizing of UIImages that are backed by a CGImage, preserves rotation metadata and scale.

###UILabel+RHSizeAdditions
Adds some simple `widthForHeight:` etc. methods.

###UIView+RHCompletedActionBadgeAdditions
Adds support for showing a completed action badge from a given view. eg: Upon tapping a submit button and getting a conformation from the server you could show a green checkmark over the submit buttons view.
