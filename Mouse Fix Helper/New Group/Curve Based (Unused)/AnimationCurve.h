//
//  AnimationCurve.h
//  Bezier Experiement
//
//  Created by Noah Nübling on 07.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AnimationCurve : NSObject

- (void) UnitBezierForPoint1x:(double)p1x point1y:(double)p1y point2x:(double)p2x point2y:(double)p2y;
- (double) solve: (double) x epsilon:(double)epsilon;


@end
